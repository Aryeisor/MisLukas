/// Límite mensual de gasto de una categoría (docs/06 §6.4.1). Inmutable, con
/// igualdad por valor.
class Budget {
  const Budget({
    required this.id,
    required this.categoryId,
    required this.month,
    required this.limitAmount,
  });

  final String id;
  final String categoryId;

  /// Primer día del mes.
  final DateTime month;

  /// Límite en pesos, mayor que cero.
  final int limitAmount;

  @override
  bool operator ==(Object other) =>
      other is Budget &&
      other.id == id &&
      other.categoryId == categoryId &&
      other.month == month &&
      other.limitAmount == limitAmount;

  @override
  int get hashCode => Object.hash(id, categoryId, month, limitAmount);

  @override
  String toString() => 'Budget($id, $categoryId, $month)';
}
