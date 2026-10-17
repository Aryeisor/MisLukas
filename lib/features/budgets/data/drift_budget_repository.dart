import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/sql_converters.dart';
import '../../../core/sync/sync_operation.dart';
import '../../../core/sync/sync_status.dart';
import '../domain/entities/budget.dart';
import '../domain/repositories/budget_repository.dart';
import 'budget_mappers.dart';

/// Presupuestos en la base local (Drift). Cada escritura y su entrada en la
/// cola de sincronización van en la misma transacción.
class DriftBudgetRepository implements BudgetRepository {
  DriftBudgetRepository(this._db);

  final AppDatabase _db;

  SimpleSelectStatement<$BudgetsTable, BudgetRow> _forMonth(DateTime month) =>
      _db.select(_db.budgets)
        ..where((t) => t.month.equalsValue(month) & t.deletedAt.isNull());

  @override
  Stream<List<Budget>> watchForMonth(DateTime month) =>
      _forMonth(month).watch().map(_toEntities);

  @override
  Future<List<Budget>> getForMonth(DateTime month) =>
      _forMonth(month).get().then(_toEntities);

  @override
  Future<Budget> save(Budget budget, {required DateTime at}) {
    return _db.transaction(() async {
      // Solo entre los no eliminados: un presupuesto eliminado no revive (la
      // eliminación prevalece al sincronizar), se crea otro con id nuevo.
      final existing =
          await (_db.select(_db.budgets)..where(
                (t) =>
                    t.categoryId.equals(budget.categoryId) &
                    t.month.equalsValue(budget.month) &
                    t.deletedAt.isNull(),
              ))
              .getSingleOrNull();

      if (existing == null) {
        await _db.enqueueSync(
          table: _db.budgets,
          recordId: budget.id,
          operation: SyncOperation.create,
          at: at,
        );
        await _db.into(_db.budgets).insert(budget.toCompanion(at: at));
        return budget;
      }

      await _db.enqueueSync(
        table: _db.budgets,
        recordId: existing.id,
        operation: SyncOperation.update,
        at: at,
      );
      await (_db.update(
        _db.budgets,
      )..where((t) => t.id.equals(existing.id))).write(
        BudgetsCompanion(
          limitAmount: Value(budget.limitAmount),
          updatedAt: Value(at.toUtc()),
          syncStatus: Value(syncStatusSqlValues[SyncStatus.pending]!),
        ),
      );
      return Budget(
        id: existing.id,
        categoryId: budget.categoryId,
        month: existing.month,
        limitAmount: budget.limitAmount,
      );
    });
  }

  static List<Budget> _toEntities(List<BudgetRow> rows) => [
    for (final row in rows) row.toEntity(),
  ];
}
