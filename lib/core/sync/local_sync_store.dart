import 'dart:math';

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/sql_converters.dart';
import 'remote_json.dart';
import 'sync_log.dart';
import 'sync_operation.dart';
import 'sync_status.dart';
import 'sync_tables.dart';

/// Registro de la cola listo para enviar: todas sus entradas hasta
/// [maxEntryId] se envían juntas con el estado actual de la fila.
class QueuedRecord {
  const QueuedRecord({
    required this.table,
    required this.id,
    required this.maxEntryId,
    required this.attempts,
  });

  final String table;
  final String id;
  final int maxEntryId;

  /// Rechazos anteriores del servidor.
  final int attempts;
}

/// Cambios pendientes, para mostrar al usuario (RF-47).
class QueueSummary {
  const QueueSummary({this.entries = 0, this.pending = 0, this.rejected = 0});

  /// Entradas en la cola: crece con cada escritura local.
  final int entries;

  /// Registros con cambios sin enviar (incluye los rechazados).
  final int pending;

  /// Registros que el servidor rechazó y esperan su próximo intento.
  final int rejected;
}

/// Espera antes de reintentar un registro rechazado [attempts] veces:
/// 5 min, 10 min, 20 min… hasta 24 h.
Duration rejectedRetryDelay(int attempts) {
  const base = Duration(minutes: 5);
  const max = Duration(hours: 24);
  final factor = pow(2, (attempts - 1).clamp(0, 20)).toInt();
  final delay = base * factor;
  return delay > max ? max : delay;
}

/// Acceso a la base local para la sincronización. Todas las consultas son de
/// Drift y van parametrizadas.
class LocalSyncStore {
  LocalSyncStore(this._db);

  final AppDatabase _db;

  static final String _synced = syncStatusSqlValues[SyncStatus.synced]!;
  static final String _pending = syncStatusSqlValues[SyncStatus.pending]!;
  static final String _error = syncStatusSqlValues[SyncStatus.error]!;

  // Cola --------------------------------------------------------------------

  /// Registros de la cola que ya se pueden enviar, agrupados por tabla y
  /// registro. Con [includeDeferred] también los rechazados que esperan su
  /// próximo intento (antes de cerrar sesión).
  Future<List<QueuedRecord>> dueRecords(
    DateTime now, {
    bool includeDeferred = false,
  }) async {
    final query = _db.select(_db.syncQueue)
      ..orderBy([(t) => OrderingTerm.asc(t.id)]);
    if (!includeDeferred) {
      query.where(
        (t) =>
            t.nextAttemptAt.isNull() |
            t.nextAttemptAt.isSmallerOrEqualValue(now.toUtc()),
      );
    }
    final entries = await query.get();

    final records = <(String, String), QueuedRecord>{};
    for (final entry in entries) {
      final key = (entry.targetTable, entry.recordId);
      final previous = records[key];
      records[key] = QueuedRecord(
        table: entry.targetTable,
        id: entry.recordId,
        maxEntryId: entry.id,
        attempts: max(previous?.attempts ?? 0, entry.attempts),
      );
    }
    return records.values.toList();
  }

  Future<bool> hasDueRecords(DateTime now) async =>
      (await dueRecords(now)).isNotEmpty;

  /// Resumen de la cola cada vez que cambia.
  Stream<QueueSummary> watchSummary() =>
      _db.select(_db.syncQueue).watch().map(_summarize);

  Future<QueueSummary> summary() =>
      _db.select(_db.syncQueue).get().then(_summarize);

  static QueueSummary _summarize(List<SyncQueueEntry> entries) {
    final pending = <(String, String)>{};
    final rejected = <(String, String)>{};
    for (final entry in entries) {
      final key = (entry.targetTable, entry.recordId);
      pending.add(key);
      if (entry.nextAttemptAt != null) rejected.add(key);
    }
    return QueueSummary(
      entries: entries.length,
      pending: pending.length,
      rejected: rejected.length,
    );
  }

  /// Filas locales de [ids] (las que existan).
  Future<List<DataClass>> rows(SyncTableOps table, List<String> ids) {
    final idColumn = table.idColumn(_db);
    return (_db.select(
      table.table(_db),
    )..where((_) => idColumn.isIn(ids))).get();
  }

  /// El servidor confirmó el registro: saca sus entradas enviadas y, si no
  /// hubo cambios durante el envío, lo deja sincronizado.
  Future<void> confirm(SyncTableOps table, QueuedRecord record) {
    return _db.transaction(() async {
      await _deleteEntries(record.table, record.id, upTo: record.maxEntryId);
      if (!await _hasEntries(record.table, record.id)) {
        await _writeStatus(table, record.id, _synced);
      }
    });
  }

  /// Saca de la cola entradas que no se deben enviar (el registro ya no
  /// existe o es fijo).
  Future<void> drop(QueuedRecord record) =>
      _deleteEntries(record.table, record.id, upTo: record.maxEntryId);

  /// El servidor rechazó el registro con [code]. Las entradas quedan en la
  /// cola con su próximo intento; no se reintenta en bucle.
  ///
  /// Con [deferFirst], el primer rechazo no cuenta como error: es un choque
  /// de "único entre activos" que el pull resuelve en la misma ejecución.
  Future<void> reject(
    SyncTableOps table,
    QueuedRecord record,
    String code, {
    required DateTime now,
    bool deferFirst = false,
  }) {
    final attempts = record.attempts + 1;
    final deferred = deferFirst && record.attempts == 0;
    syncLog(table.name, 'rechazado', code: code, attempt: attempts);
    return _db.transaction(() async {
      await (_db.update(_db.syncQueue)..where(
            (t) =>
                t.targetTable.equals(record.table) &
                t.recordId.equals(record.id) &
                t.id.isSmallerOrEqualValue(record.maxEntryId),
          ))
          .write(
            SyncQueueCompanion(
              attempts: Value(attempts),
              lastError: Value(code),
              nextAttemptAt: Value(
                deferred ? null : now.toUtc().add(rejectedRetryDelay(attempts)),
              ),
            ),
          );
      if (!deferred) await _writeStatus(table, record.id, _error);
    });
  }

  // Cursores ----------------------------------------------------------------

  /// Mayor sincronizado_en recibido de [table]; null si nunca se recibió.
  Future<DateTime?> cursor(String table) async {
    final row = await (_db.select(
      _db.syncMetadata,
    )..where((t) => t.targetTable.equals(table))).getSingleOrNull();
    return row?.lastSyncedAt;
  }

  // Pull --------------------------------------------------------------------

  /// Aplica una página de filas remotas y avanza el cursor, en una sola
  /// transacción. Devuelve true si quedó algo nuevo en la cola (por un choque
  /// de "único entre activos" o una eliminación local que faltaba enviar).
  Future<bool> applyPage(
    SyncTableOps table,
    List<Map<String, dynamic>> rows, {
    required DateTime now,
  }) {
    return _db.transaction(() async {
      var enqueued = false;
      DateTime? maxSyncedAt = await cursor(table.name);
      for (final json in rows) {
        final syncedAt = RemoteJson(json).timestamp('sincronizado_en');
        if (maxSyncedAt == null || syncedAt.isAfter(maxSyncedAt)) {
          maxSyncedAt = syncedAt;
        }
        try {
          if (await _applyRow(table, json, now)) enqueued = true;
        } on FormatException {
          syncLog(table.name, 'fila remota inválida');
        } on ArgumentError {
          syncLog(table.name, 'fila remota inválida');
        } catch (_) {
          // Por ejemplo, una llave foránea local: se salta la fila.
          syncLog(table.name, 'fila remota no aplicada');
        }
      }
      if (maxSyncedAt != null) {
        await _db
            .into(_db.syncMetadata)
            .insertOnConflictUpdate(
              SyncMetadataCompanion.insert(
                targetTable: table.name,
                lastSyncedAt: Value(maxSyncedAt.toUtc()),
              ),
            );
      }
      return enqueued;
    });
  }

  /// Reglas de docs/06 §6.6.3 para una fila remota. Devuelve true si encoló
  /// algo.
  Future<bool> _applyRow(
    SyncTableOps table,
    Map<String, dynamic> json,
    DateTime now,
  ) async {
    final remote = table.parse(json);
    if (table.isFixedRemote(remote)) return false;
    final info = table.remoteInfo(remote);
    final local = await _find(table, info.id);

    if (local == null) {
      // Registro nuevo, o eliminado que llega como lápida (no puede revivir).
      if (!info.isDeleted &&
          await _remoteLosesActiveKey(table, remote, info, now)) {
        await _db
            .into(table.table(_db))
            .insert(table.asDeletedCompanion(remote, now));
        await _enqueue(table, info.id, SyncOperation.delete, now);
        return true;
      }
      final enqueued =
          !info.isDeleted && await _resolveActiveKey(table, remote, info, now);
      await _db.into(table.table(_db)).insert(table.toCompanion(remote));
      return enqueued;
    }

    final localInfo = table.localInfo(local);
    final pending = await _hasEntries(table.name, info.id);

    // La eliminación prevalece: un registro eliminado aquí no revive.
    if (localInfo.isDeleted && !info.isDeleted) {
      if (pending) return false;
      // La eliminación no llegó al servidor: se vuelve a enviar.
      await _writeStatus(table, info.id, _pending);
      await _enqueue(table, info.id, SyncOperation.delete, now);
      return true;
    }

    // Última escritura gana, salvo que el servidor traiga una eliminación.
    if (!info.isDeleted &&
        pending &&
        localInfo.updatedAt.isAfter(info.updatedAt)) {
      return false;
    }
    if (!pending && table.sameAs(local, remote)) return false;

    // Gana la versión remota; la local, si estaba pendiente, se descarta.
    if (!info.isDeleted &&
        !localInfo.isDeleted &&
        await _remoteLosesActiveKey(table, remote, info, now)) {
      await _replace(table, info.id, table.asDeletedCompanion(remote, now));
      await _deleteEntries(table.name, info.id);
      await _enqueue(table, info.id, SyncOperation.delete, now);
      return true;
    }
    final enqueued =
        !info.isDeleted && await _resolveActiveKey(table, remote, info, now);
    await _replace(table, info.id, table.toCompanion(remote));
    await _deleteEntries(table.name, info.id);
    return enqueued;
  }

  /// Si el registro remoto choca con uno local activo de la misma llave
  /// "única entre activos" y pierde, devuelve true. Gana el de
  /// actualizado_en mayor; si empatan, el de id mayor. Así los dos
  /// dispositivos eligen el mismo.
  Future<bool> _remoteLosesActiveKey(
    SyncTableOps table,
    Object remote,
    SyncRecordInfo info,
    DateTime now,
  ) async {
    for (final other in await _activeConflicts(table, remote, info)) {
      if (!_wins(info, table.localInfo(other))) return true;
    }
    return false;
  }

  /// El registro remoto ganó: elimina los locales activos que chocan con él
  /// y los encola. Devuelve true si eliminó alguno.
  Future<bool> _resolveActiveKey(
    SyncTableOps table,
    Object remote,
    SyncRecordInfo info,
    DateTime now,
  ) async {
    final conflicts = await _activeConflicts(table, remote, info);
    for (final other in conflicts) {
      final otherId = table.localInfo(other).id;
      await _replace(
        table,
        otherId,
        table.rawValues({
          'eliminado_en': Variable<DateTime>(now.toUtc()),
          'actualizado_en': Variable<DateTime>(now.toUtc()),
          'estado_sync': Variable<String>(_pending),
        }),
      );
      await _enqueue(table, otherId, SyncOperation.delete, now);
    }
    return conflicts.isNotEmpty;
  }

  Future<List<DataClass>> _activeConflicts(
    SyncTableOps table,
    Object remote,
    SyncRecordInfo info,
  ) async {
    final key = table.activeKey(_db, remote);
    if (key == null) return const [];
    final idColumn = table.idColumn(_db);
    final deletedAt = table.deletedAtColumn(_db);
    return (_db.select(table.table(_db))..where(
          (_) => key & idColumn.equals(info.id).not() & deletedAt.isNull(),
        ))
        .get();
  }

  static bool _wins(SyncRecordInfo a, SyncRecordInfo b) {
    if (a.updatedAt.isAfter(b.updatedAt)) return true;
    if (b.updatedAt.isAfter(a.updatedAt)) return false;
    return a.id.compareTo(b.id) > 0;
  }

  // Auxiliares ----------------------------------------------------------------

  Future<DataClass?> _find(SyncTableOps table, String id) {
    final idColumn = table.idColumn(_db);
    return (_db.select(
      table.table(_db),
    )..where((_) => idColumn.equals(id))).getSingleOrNull();
  }

  Future<void> _replace(
    SyncTableOps table,
    String id,
    Insertable<DataClass> values,
  ) {
    final idColumn = table.idColumn(_db);
    return (_db.update(
      table.table(_db),
    )..where((_) => idColumn.equals(id))).write(values);
  }

  Future<void> _writeStatus(SyncTableOps table, String id, String status) =>
      _replace(
        table,
        id,
        table.rawValues({'estado_sync': Variable<String>(status)}),
      );

  Future<void> _enqueue(
    SyncTableOps table,
    String id,
    SyncOperation operation,
    DateTime now,
  ) => _db.enqueueSync(
    table: table.table(_db),
    recordId: id,
    operation: operation,
    at: now,
  );

  Future<bool> _hasEntries(String table, String id) async {
    final entry =
        await (_db.select(_db.syncQueue)
              ..where(
                (t) => t.targetTable.equals(table) & t.recordId.equals(id),
              )
              ..limit(1))
            .getSingleOrNull();
    return entry != null;
  }

  Future<void> _deleteEntries(String table, String id, {int? upTo}) {
    return (_db.delete(_db.syncQueue)..where(
          (t) =>
              t.targetTable.equals(table) &
              t.recordId.equals(id) &
              (upTo == null
                  ? const Constant(true)
                  : t.id.isSmallerOrEqualValue(upTo)),
        ))
        .go();
  }
}
