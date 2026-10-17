import 'dart:async';

import '../utils/clock.dart';
import 'local_sync_store.dart';
import 'remote_json.dart';
import 'sync_log.dart';
import 'sync_remote_source.dart';
import 'sync_tables.dart';

/// Resultado de una sincronización.
enum SyncResult {
  /// Se envió y se recibió todo lo que se podía (los registros rechazados
  /// esperan su próximo intento).
  ok,

  /// Sin conexión o el servidor no respondió: se reintenta más tarde.
  offline,

  /// Sin sesión válida: se espera a que el usuario vuelva a entrar.
  unauthorized,

  /// Falló algo en el dispositivo (por ejemplo, la base local).
  failed,

  /// El servicio ya se detuvo (cierre de sesión).
  skipped,
}

/// Sincronización entre la base local y la fuente remota (docs/06 §6.6.2):
/// primero envía (push con upsert), luego recibe (pull por sincronizado_en)
/// y, si el pull dejó algo en la cola, vuelve a enviar.
///
/// Solo corre una operación a la vez. Si se pide sincronizar durante una
/// ejecución, se hace una más al terminar y las solicitudes de ese intervalo
/// esperan esa misma.
class SyncService {
  SyncService({
    required this._store,
    required this._remote,
    required this._clock,
  });

  final LocalSyncStore _store;
  final SyncRemoteSource _remote;
  final Clock _clock;

  /// Filas por upsert.
  static const int pushBatchSize = 100;

  /// Filas por página al recibir.
  static const int pullPageSize = 200;

  /// Solape al recibir: `now()` en PostgreSQL es la hora de inicio de la
  /// transacción, así que una transacción larga puede confirmar filas con un
  /// sincronizado_en anterior al cursor. Repetirlas no cambia nada.
  static const Duration pullOverlap = Duration(minutes: 5);

  Future<void> _tail = Future.value();
  Future<SyncResult>? _waiting;
  bool _closed = false;

  /// Sincroniza. Coalesce las solicitudes que llegan durante una ejecución.
  Future<SyncResult> run() => _waiting ??= _locked(() {
    _waiting = null;
    return _syncOnce();
  });

  /// Intenta enviar todo lo pendiente, incluidos los registros rechazados
  /// que esperan su próximo intento, y devuelve cuántos registros quedan sin
  /// enviar (antes de cerrar sesión).
  Future<int> pushAll() => _locked(() async {
    if (!_closed) {
      try {
        await _remote.ensureSession();
        await _push(includeDeferred: true);
      } on SyncException {
        // Lo que no se envió queda contado abajo.
      }
    }
    return (await _store.summary()).pending;
  });

  /// Detiene el servicio: espera la operación en curso y rechaza las nuevas.
  Future<void> shutdown() async {
    _closed = true;
    await _tail;
  }

  Future<T> _locked<T>(Future<T> Function() body) {
    final result = _tail.then((_) => body());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<SyncResult> _syncOnce() async {
    if (_closed) return SyncResult.skipped;
    try {
      await _remote.ensureSession();
      await _push();
      await _pull();
      // Lo que encoló el pull o un choque de "único entre activos" diferido.
      if (await _store.hasDueRecords(_now())) await _push();
      return SyncResult.ok;
    } on SyncNetworkException {
      syncLog('sync', 'sin conexión');
      return SyncResult.offline;
    } on SyncAuthException {
      syncLog('sync', 'sesión no válida');
      return SyncResult.unauthorized;
    } on SyncRecordException catch (error) {
      // Solo llega aquí si falla una consulta de descarga.
      syncLog('sync', 'descarga rechazada', code: error.code);
      return SyncResult.failed;
    } catch (_) {
      syncLog('sync', 'error local');
      return SyncResult.failed;
    }
  }

  DateTime _now() => _clock.now().toUtc();

  // Pull ----------------------------------------------------------------------

  /// Recibe cada tabla, en el orden de las llaves foráneas, desde su cursor
  /// menos el solape, con paginación por llave (sincronizado_en, id).
  Future<void> _pull() async {
    for (final table in syncTables) {
      final cursor = await _store.cursor(table.name);
      SyncCursor? after = cursor == null
          ? null
          : SyncCursor(cursor.subtract(pullOverlap));
      while (true) {
        final rows = await _remote.fetchAfter(
          table.name,
          after: after,
          limit: pullPageSize,
        );
        if (rows.isEmpty) break;
        await _store.applyPage(table, rows, now: _now());
        if (rows.length < pullPageSize) break;
        final last = RemoteJson(rows.last);
        after = SyncCursor(
          last.timestamp('sincronizado_en'),
          last.string('id'),
        );
      }
    }
  }

  // Push ----------------------------------------------------------------------

  Future<void> _push({bool includeDeferred = false}) async {
    final records = await _store.dueRecords(
      _now(),
      includeDeferred: includeDeferred,
    );
    if (records.isEmpty) return;

    for (final table in syncTables) {
      final queued = {
        for (final record in records)
          if (record.table == table.name) record.id: record,
      };
      if (queued.isEmpty) continue;

      for (final record in queued.values.where(
        (r) => table.isFixedLocal(r.id),
      )) {
        await _store.drop(record);
      }
      queued.removeWhere((id, _) => table.isFixedLocal(id));

      final rows = await _store.rows(table, queued.keys.toList());
      final found = <String>{};
      final items = <_PushItem>[];
      for (final row in rows) {
        final info = table.localInfo(row);
        found.add(info.id);
        items.add(
          _PushItem(queued[info.id]!, table.toRemote(row), info.isDeleted),
        );
      }
      // Registros que ya no existen (por ejemplo, se borraron los datos de
      // demostración): no hay nada que enviar.
      for (final record in queued.values.where((r) => !found.contains(r.id))) {
        await _store.drop(record);
      }

      // Las eliminaciones primero: liberan la llave "única entre activos"
      // antes de que llegue el registro que la reemplaza.
      items.sort((a, b) {
        if (a.deleted != b.deleted) return a.deleted ? -1 : 1;
        return a.record.maxEntryId.compareTo(b.record.maxEntryId);
      });
      for (final batch in _batches(items)) {
        await _upsertBatch(table, batch);
      }
    }
  }

  /// Lotes de hasta [pushBatchSize] filas con las mismas columnas (PostgREST
  /// rellena con null las columnas que falten en una fila de un lote).
  static Iterable<List<_PushItem>> _batches(List<_PushItem> items) sync* {
    final bySignature = <String, List<_PushItem>>{};
    for (final item in items) {
      final signature = (item.json.keys.toList()..sort()).join(',');
      bySignature.putIfAbsent(signature, () => []).add(item);
    }
    for (final group in bySignature.values) {
      for (var i = 0; i < group.length; i += pushBatchSize) {
        yield group.sublist(
          i,
          i + pushBatchSize > group.length ? group.length : i + pushBatchSize,
        );
      }
    }
  }

  Future<void> _upsertBatch(SyncTableOps table, List<_PushItem> batch) async {
    try {
      await _remote.upsert(table.name, [for (final item in batch) item.json]);
    } on SyncRecordException catch (error) {
      if (batch.length == 1) {
        await _store.reject(
          table,
          batch.single.record,
          error.code,
          now: _now(),
          deferFirst:
              error.code == SyncRecordException.uniqueViolation &&
              table.hasActiveKey,
        );
        return;
      }
      // Un registro con error no bloquea el resto: se reenvía de a uno para
      // encontrarlo.
      for (final item in batch) {
        await _upsertBatch(table, [item]);
      }
      return;
    }
    for (final item in batch) {
      await _store.confirm(table, item.record);
    }
  }
}

class _PushItem {
  const _PushItem(this.record, this.json, this.deleted);

  final QueuedRecord record;
  final Map<String, dynamic> json;
  final bool deleted;
}
