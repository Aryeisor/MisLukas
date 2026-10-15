import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/sql_converters.dart';
import '../../../core/sync/sync_status.dart';
import '../../movements/data/movement_mappers.dart';
import '../domain/entities/budget.dart';
import '../domain/entities/category.dart';
import '../domain/entities/default_categories.dart';

// Conversión entre filas de Drift y entidades de dominio de categorías y
// presupuestos.

extension CategoryRowMapper on CategoryRow {
  /// La clave y si es predeterminada salen del UUID fijo, no de una columna:
  /// así el esquema local es igual al de Supabase.
  Category toEntity() {
    final defaultCategory = DefaultCategory.fromId(id);
    return Category(
      id: id,
      key: defaultCategory?.key,
      name: name,
      type: movementTypeFromSql(type),
      isDefault: defaultCategory != null,
    );
  }
}

extension BudgetRowMapper on BudgetRow {
  Budget toEntity() => Budget(
    id: id,
    categoryId: categoryId,
    month: month,
    limitAmount: limitAmount,
  );
}

extension BudgetToCompanion on Budget {
  /// Fila nueva, pendiente de sincronizar.
  BudgetsCompanion toCompanion({required DateTime at}) =>
      BudgetsCompanion.insert(
        id: id,
        categoryId: categoryId,
        month: month,
        limitAmount: limitAmount,
        createdAt: at.toUtc(),
        updatedAt: at.toUtc(),
        syncStatus: Value(syncStatusSqlValues[SyncStatus.pending]!),
      );
}
