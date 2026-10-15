import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/entities/category.dart';
import '../domain/repositories/category_repository.dart';
import 'budget_mappers.dart';

/// Categorías en la base local (Drift).
class DriftCategoryRepository implements CategoryRepository {
  DriftCategoryRepository(this._db);

  final AppDatabase _db;

  SimpleSelectStatement<$CategoriesTable, CategoryRow> get _active =>
      _db.select(_db.categories)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.name)]);

  @override
  Stream<List<Category>> watchAll() => _active.watch().map(_toEntities);

  @override
  Future<List<Category>> getAll() => _active.get().then(_toEntities);

  @override
  Future<Category?> findById(String id) async {
    final row = await (_db.select(
      _db.categories,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    return row?.toEntity();
  }

  static List<Category> _toEntities(List<CategoryRow> rows) => [
    for (final row in rows) row.toEntity(),
  ];
}
