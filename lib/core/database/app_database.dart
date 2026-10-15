import 'package:drift/drift.dart';

import '../../features/budgets/domain/entities/default_categories.dart';
import '../../features/movements/data/movement_mappers.dart';
import '../sync/sync_operation.dart';
import '../sync/sync_status.dart';
import 'sql_converters.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// Fecha de creación de las categorías predeterminadas: fija para que el
/// registro sea igual en todos los dispositivos.
final DateTime defaultCategoriesCreatedAt = DateTime.utc(2026, 1, 1);

/// Base local de MisLukas (docs/06 §6.4.3). La apertura cifrada está en
/// `database_connection.dart`; las pruebas usan una base en memoria.
@DriftDatabase(
  tables: [Categories, Movements, Budgets, Receipts, SyncQueue, SyncMetadata],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _insertDefaultCategories();
    },
    beforeOpen: (details) async {
      // SQLite trae las llaves foráneas desactivadas por defecto.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Las categorías predeterminadas también existen en el servidor, por eso
  /// nacen sincronizadas y no entran a la cola.
  Future<void> _insertDefaultCategories() {
    return batch((batch) {
      batch.insertAll(categories, [
        for (final category in DefaultCategory.values)
          CategoriesCompanion.insert(
            id: category.id,
            name: category.displayName,
            type: movementTypeToSql(category.type),
            icon: Value(category.key),
            createdAt: defaultCategoriesCreatedAt,
            updatedAt: defaultCategoriesCreatedAt,
            syncStatus: Value(syncStatusSqlValues[SyncStatus.synced]!),
          ),
      ]);
    });
  }

  /// Agrega un cambio a la cola de sincronización. Debe llamarse dentro de la
  /// misma transacción que escribe el registro.
  Future<void> enqueueSync({
    required TableInfo<Table, Object?> table,
    required String recordId,
    required SyncOperation operation,
    required DateTime at,
  }) {
    return into(syncQueue).insert(
      SyncQueueCompanion.insert(
        targetTable: table.actualTableName,
        recordId: recordId,
        operation: operation.sqlValue,
        createdAt: at.toUtc(),
      ),
    );
  }
}
