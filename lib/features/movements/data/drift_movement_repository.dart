import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/sql_converters.dart';
import '../../../core/sync/sync_operation.dart';
import '../../../core/sync/sync_status.dart';
import '../domain/entities/movement.dart';
import '../domain/entities/receipt.dart';
import '../domain/repositories/movement_repository.dart';
import 'movement_mappers.dart';

/// Movimientos en la base local (Drift). Cada escritura y su entrada en la
/// cola de sincronización van en la misma transacción: si una falla, ninguna
/// queda guardada.
class DriftMovementRepository implements MovementRepository {
  DriftMovementRepository(this._db);

  final AppDatabase _db;

  static const SqlDateConverter _dates = SqlDateConverter();

  @override
  Future<void> add(Movement movement, {Receipt? receipt}) {
    return _db.transaction(() async {
      await _db.enqueueSync(
        table: _db.movements,
        recordId: movement.id,
        operation: SyncOperation.create,
        at: movement.updatedAt,
      );
      await _db.into(_db.movements).insert(movement.toCompanion());

      if (receipt != null) {
        await _db.enqueueSync(
          table: _db.receipts,
          recordId: receipt.id,
          operation: SyncOperation.create,
          at: movement.updatedAt,
        );
        await _db
            .into(_db.receipts)
            .insert(receipt.toCompanion(at: movement.updatedAt));
      }
    });
  }

  @override
  Future<void> update(Movement movement) {
    return _db.transaction(() async {
      await _db.enqueueSync(
        table: _db.movements,
        recordId: movement.id,
        operation: SyncOperation.update,
        at: movement.updatedAt,
      );
      final companion = movement.toCompanion().copyWith(
        // El momento de creación no cambia al editar.
        createdAt: const Value.absent(),
      );
      final updated =
          await (_db.update(_db.movements)
                ..where((t) => t.id.equals(movement.id) & t.deletedAt.isNull()))
              .write(companion);
      if (updated == 0) {
        // Revierte la entrada de la cola.
        throw StateError('Movimiento inexistente o eliminado: ${movement.id}');
      }
    });
  }

  @override
  Future<void> softDelete(String id, {required DateTime at}) {
    final deletedAt = Value<DateTime?>(at.toUtc());
    final updatedAt = Value(at.toUtc());
    final pending = Value(syncStatusSqlValues[SyncStatus.pending]!);
    return _db.transaction(() async {
      await _db.enqueueSync(
        table: _db.movements,
        recordId: id,
        operation: SyncOperation.delete,
        at: at,
      );
      final deleted =
          await (_db.update(
            _db.movements,
          )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
            MovementsCompanion(
              deletedAt: deletedAt,
              updatedAt: updatedAt,
              syncStatus: pending,
            ),
          );
      if (deleted == 0) {
        throw StateError('Movimiento inexistente o eliminado: $id');
      }

      // El recibo sigue al movimiento.
      final receipt =
          await (_db.select(_db.receipts)
                ..where((t) => t.movementId.equals(id) & t.deletedAt.isNull()))
              .getSingleOrNull();
      if (receipt != null) {
        await _db.enqueueSync(
          table: _db.receipts,
          recordId: receipt.id,
          operation: SyncOperation.delete,
          at: at,
        );
        await (_db.update(
          _db.receipts,
        )..where((t) => t.id.equals(receipt.id))).write(
          ReceiptsCompanion(
            deletedAt: deletedAt,
            updatedAt: updatedAt,
            syncStatus: pending,
          ),
        );
      }
    });
  }

  @override
  Future<Movement?> findById(String id) async {
    final row = await (_db.select(
      _db.movements,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    return row?.toEntity();
  }

  @override
  Stream<List<Movement>> watchRecent({required int limit}) {
    final query = _db.select(_db.movements)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy(_newestFirst)
      ..limit(limit);
    return query.watch().map(_toEntities);
  }

  @override
  Stream<List<Movement>> watchBetween(DateTime from, DateTime to) =>
      _between(from, to).watch().map(_toEntities);

  @override
  Future<List<Movement>> getBetween(DateTime from, DateTime to) =>
      _between(from, to).get().then(_toEntities);

  /// Fecha en [from, to). Las fechas son texto 'AAAA-MM-DD', que se comparan
  /// en orden; los valores viajan como parámetros.
  SimpleSelectStatement<$MovementsTable, MovementRow> _between(
    DateTime from,
    DateTime to,
  ) {
    return _db.select(_db.movements)
      ..where(
        (t) =>
            t.deletedAt.isNull() &
            t.date.isBiggerOrEqualValue(_dates.toSql(from)) &
            t.date.isSmallerThanValue(_dates.toSql(to)),
      )
      ..orderBy(_newestFirst);
  }

  static List<OrderingTerm Function($MovementsTable)> get _newestFirst => [
    (t) => OrderingTerm.desc(t.date),
    (t) => OrderingTerm.desc(t.createdAt),
  ];

  static List<Movement> _toEntities(List<MovementRow> rows) => [
    for (final row in rows) row.toEntity(),
  ];
}
