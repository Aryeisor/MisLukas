import 'movement.dart';

/// Filtro del historial (RF-22): por tipo, por categoría o ambos. Inmutable,
/// con igualdad por valor.
class MovementFilter {
  const MovementFilter({this.type, this.categoryId});

  /// Sin filtro: todos los movimientos.
  static const MovementFilter all = MovementFilter();

  /// Solo gastos o solo ingresos; null para los dos.
  final MovementType? type;

  /// Solo los de esta categoría; null para todas.
  final String? categoryId;

  bool get isEmpty => type == null && categoryId == null;

  /// Indica si [movement] cumple el filtro.
  bool matches(Movement movement) =>
      (type == null || movement.type == type) &&
      (categoryId == null || movement.categoryId == categoryId);

  @override
  bool operator ==(Object other) =>
      other is MovementFilter &&
      other.type == type &&
      other.categoryId == categoryId;

  @override
  int get hashCode => Object.hash(type, categoryId);

  @override
  String toString() => 'MovementFilter(${type?.name}, $categoryId)';
}
