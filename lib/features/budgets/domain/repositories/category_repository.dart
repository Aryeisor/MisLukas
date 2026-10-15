import '../entities/category.dart';

/// Acceso a las categorías. Las consultas excluyen las eliminadas.
abstract interface class CategoryRepository {
  /// Todas las categorías, ordenadas por nombre.
  Stream<List<Category>> watchAll();

  Future<List<Category>> getAll();

  Future<Category?> findById(String id);
}
