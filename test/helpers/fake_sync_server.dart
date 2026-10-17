import 'dart:async';

import 'package:mislukas/core/sync/remote_json.dart';
import 'package:mislukas/core/sync/sync_remote_source.dart';
import 'package:mislukas/core/utils/clock.dart';
import 'package:mislukas/core/utils/id_generator.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';
import 'package:mislukas/features/movements/data/movement_mappers.dart';

/// Reloj que se puede adelantar en las pruebas.
class MutableClock implements Clock {
  MutableClock(this._now);

  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration duration) => _now = _now.add(duration);

  set current(DateTime value) => _now = value;
}

/// Identificadores distintos por dispositivo: a-1, a-2… y b-1, b-2…
class PrefixedIdGenerator implements IdGenerator {
  PrefixedIdGenerator(this.prefix);

  final String prefix;
  int _next = 0;

  @override
  String newId() => '$prefix-${++_next}';
}

/// Llamada registrada por el servidor falso.
class FakeServerCall {
  const FakeServerCall(this.user, this.method, this.table, this.ids);

  final String user;
  final String method;
  final String table;
  final List<String> ids;

  @override
  String toString() => '$method $table $ids';
}

/// Servidor de Supabase en memoria y sin red, con las reglas del esquema
/// remoto: usuario_id por defecto (auth.uid()), sincronizado_en asignado por
/// el servidor, RLS por usuario, categorías predeterminadas globales, la
/// última escritura gana y la eliminación prevalece (migración 009), y los
/// índices únicos parciales de presupuestos y recibos.
class FakeSyncServer {
  FakeSyncServer({DateTime? start})
    : _now = start ?? DateTime.utc(2026, 9, 22, 15) {
    for (final category in DefaultCategory.values) {
      _tables['categorias']![category.id] = {
        'id': category.id,
        'usuario_id': null,
        'nombre': category.displayName,
        'tipo': movementTypeToSql(category.type),
        'icono': category.key,
        'color': null,
        'creado_en': '2026-01-01T00:00:00.000Z',
        'actualizado_en': '2026-01-01T00:00:00.000Z',
        'eliminado_en': null,
        'sincronizado_en': '2026-01-01T00:00:00.000Z',
      };
    }
  }

  DateTime _now;
  final Map<String, Map<String, Map<String, dynamic>>> _tables = {
    'categorias': {},
    'movimientos': {},
    'presupuestos': {},
    'recibos': {},
  };

  /// Sin conexión: toda llamada lanza [SyncNetworkException].
  bool offline = false;

  /// La sesión del usuario fue rechazada.
  bool sessionRejected = false;

  /// Registros que el servidor rechaza, con su código.
  final Map<String, String> rejectedIds = {};

  /// Llamadas recibidas, en orden.
  final List<FakeServerCall> calls = [];

  /// Se llama dentro de cada upsert, antes de confirmar (por ejemplo, para
  /// simular una edición local durante el envío o retener la respuesta).
  FutureOr<void> Function(String table, List<Map<String, dynamic>> rows)?
  onUpsert;

  /// Fuente remota de [userId], como si llevara su token.
  SyncRemoteSource sourceFor(String userId) => _FakeSource(this, userId);

  /// Filas de [table] (copias), incluidas las de todos los usuarios.
  List<Map<String, dynamic>> rows(String table) => [
    for (final row in _tables[table]!.values) Map.of(row),
  ];

  Map<String, dynamic>? row(String table, String id) {
    final row = _tables[table]![id];
    return row == null ? null : Map.of(row);
  }

  /// Escribe una fila directamente, como otra sesión o una transacción larga
  /// que confirma con un sincronizado_en anterior ([syncedAt]).
  void putRow(
    String table,
    Map<String, dynamic> row, {
    required String userId,
    DateTime? syncedAt,
  }) {
    _tables[table]![row['id'] as String] = {
      ...row,
      'usuario_id': userId,
      'sincronizado_en': (syncedAt ?? _tick()).toUtc().toIso8601String(),
    };
  }

  /// Borra todos los datos de [userId] (eliminación de la cuenta).
  void deleteUser(String userId) {
    for (final table in _tables.values) {
      table.removeWhere((_, row) => row['usuario_id'] == userId);
    }
  }

  /// Hora del servidor de la siguiente transacción: avanza 1 ms cada vez.
  DateTime _tick() => _now = _now.add(const Duration(milliseconds: 1));

  void _check() {
    if (offline) throw const SyncNetworkException();
    if (sessionRejected) throw const SyncAuthException();
  }

  Future<void> _upsert(
    String user,
    String table,
    List<Map<String, dynamic>> rows,
  ) async {
    _check();
    calls.add(
      FakeServerCall(user, 'upsert', table, [
        for (final row in rows) row['id'] as String,
      ]),
    );
    await onUpsert?.call(table, rows);
    _check();

    // Una transacción: si una fila falla, no se aplica ninguna.
    final working = {
      for (final entry in _tables[table]!.entries) entry.key: entry.value,
    };
    final syncedAt = _tick().toIso8601String();
    for (final incoming in rows) {
      final id = incoming['id'] as String;
      final code = rejectedIds[id];
      if (code != null) throw SyncRecordException(code);
      if (table == 'categorias' && DefaultCategory.fromId(id) != null) {
        throw const SyncRecordException('42501');
      }

      final existing = working[id];
      if (existing != null && existing['usuario_id'] != user) {
        // RLS: la fila de otro usuario no es visible para el update.
        throw const SyncRecordException('42501');
      }
      if (existing != null && !_acceptsUpdate(existing, incoming)) continue;

      final merged = {
        ...?existing,
        ...incoming,
        'usuario_id': user,
        'sincronizado_en': syncedAt,
      };
      _checkActiveUnique(working, table, merged);
      if (table == 'recibos' && _isActive(merged)) {
        final movement = _tables['movimientos']![merged['movimiento_id']];
        if (movement == null || movement['usuario_id'] != user) {
          throw const SyncRecordException('23503');
        }
      }
      working[id] = merged;
    }
    _tables[table] = working;
  }

  /// Trigger conservar_ultima_escritura (migración 009).
  static bool _acceptsUpdate(
    Map<String, dynamic> old,
    Map<String, dynamic> incoming,
  ) {
    if (old['eliminado_en'] != null) return false;
    if (incoming['eliminado_en'] != null) return true;
    final oldUpdated = DateTime.parse(old['actualizado_en'] as String);
    final newUpdated = DateTime.parse(incoming['actualizado_en'] as String);
    return !newUpdated.isBefore(oldUpdated);
  }

  static bool _isActive(Map<String, dynamic> row) =>
      row['eliminado_en'] == null;

  static void _checkActiveUnique(
    Map<String, Map<String, dynamic>> rows,
    String table,
    Map<String, dynamic> row,
  ) {
    if (!_isActive(row)) return;
    final keys = switch (table) {
      'presupuestos' => ['usuario_id', 'categoria_id', 'mes'],
      'recibos' => ['usuario_id', 'movimiento_id'],
      _ => null,
    };
    if (keys == null) return;
    for (final other in rows.values) {
      if (other['id'] == row['id'] || !_isActive(other)) continue;
      if (keys.every((k) => other[k] == row[k])) {
        throw const SyncRecordException(SyncRecordException.uniqueViolation);
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAfter(
    String user,
    String table, {
    required SyncCursor? after,
    required int limit,
  }) async {
    _check();
    calls.add(FakeServerCall(user, 'select', table, const []));
    final visible =
        _tables[table]!.values
            .where(
              (row) =>
                  row['usuario_id'] == user ||
                  (table == 'categorias' && row['usuario_id'] == null),
            )
            .toList()
          ..sort((a, b) {
            final byTime = _syncedAt(a).compareTo(_syncedAt(b));
            return byTime != 0
                ? byTime
                : (a['id'] as String).compareTo(b['id'] as String);
          });
    return [
      for (final row in visible)
        if (_isAfter(row, after)) Map.of(row),
    ].take(limit).toList();
  }

  static DateTime _syncedAt(Map<String, dynamic> row) =>
      RemoteJson(row).timestamp('sincronizado_en');

  static bool _isAfter(Map<String, dynamic> row, SyncCursor? after) {
    if (after == null) return true;
    final syncedAt = _syncedAt(row);
    final id = after.id;
    if (id == null) return !syncedAt.isBefore(after.syncedAt);
    return syncedAt.isAfter(after.syncedAt) ||
        (syncedAt.isAtSameMomentAs(after.syncedAt) &&
            (row['id'] as String).compareTo(id) > 0);
  }
}

class _FakeSource implements SyncRemoteSource {
  _FakeSource(this._server, this._user);

  final FakeSyncServer _server;
  final String _user;

  @override
  Future<void> ensureSession() async => _server._check();

  @override
  Future<void> upsert(String table, List<Map<String, dynamic>> rows) =>
      _server._upsert(_user, table, rows);

  @override
  Future<List<Map<String, dynamic>>> fetchAfter(
    String table, {
    required SyncCursor? after,
    required int limit,
  }) => _server._fetchAfter(_user, table, after: after, limit: limit);
}
