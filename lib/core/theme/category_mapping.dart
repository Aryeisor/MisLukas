import '../../features/budgets/domain/entities/default_categories.dart';
import 'category_style.dart';

// Único lugar donde se relacionan las categorías predeterminadas del dominio
// (UUID fijos) con su estilo visual (CategoryKind).

extension DefaultCategoryStyle on DefaultCategory {
  CategoryKind get kind => switch (this) {
    DefaultCategory.mercado => CategoryKind.mercado,
    DefaultCategory.transporte => CategoryKind.transporte,
    DefaultCategory.ocio => CategoryKind.ocio,
    DefaultCategory.servicios => CategoryKind.servicios,
    DefaultCategory.restaurantes => CategoryKind.restaurantes,
    DefaultCategory.otros => CategoryKind.otros,
    DefaultCategory.ingreso => CategoryKind.ingreso,
  };
}

extension CategoryKindDefault on CategoryKind {
  DefaultCategory get defaultCategory => switch (this) {
    CategoryKind.mercado => DefaultCategory.mercado,
    CategoryKind.transporte => DefaultCategory.transporte,
    CategoryKind.ocio => DefaultCategory.ocio,
    CategoryKind.servicios => DefaultCategory.servicios,
    CategoryKind.restaurantes => DefaultCategory.restaurantes,
    CategoryKind.otros => DefaultCategory.otros,
    CategoryKind.ingreso => DefaultCategory.ingreso,
  };

  /// UUID fijo de la categoría en la base.
  String get categoryId => defaultCategory.id;
}

/// Estilo de la categoría con [categoryId]. Las personalizadas (futuro) usan
/// el estilo de Otros.
CategoryKind categoryKindForId(String categoryId) =>
    DefaultCategory.fromId(categoryId)?.kind ?? CategoryKind.otros;
