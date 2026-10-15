import 'category_spending.dart';

/// Variación del gasto de una categoría frente al mes anterior. Inmutable, con
/// igualdad por valor.
class CategoryVariation {
  const CategoryVariation({
    required this.categoryId,
    required this.currentAmount,
    required this.previousAmount,
    required this.percentChange,
  });

  final String categoryId;
  final int currentAmount;

  /// Gasto del mes anterior, siempre mayor que cero.
  final int previousAmount;

  /// Variación porcentual redondeada: positiva si aumentó.
  final int percentChange;

  bool get isIncrease => percentChange > 0;

  @override
  bool operator ==(Object other) =>
      other is CategoryVariation &&
      other.categoryId == categoryId &&
      other.currentAmount == currentAmount &&
      other.previousAmount == previousAmount &&
      other.percentChange == percentChange;

  @override
  int get hashCode =>
      Object.hash(categoryId, currentAmount, previousAmount, percentChange);

  @override
  String toString() => 'CategoryVariation($categoryId, $percentChange%)';
}

/// Comparación de los gastos de un mes con el anterior (RF-35).
class MonthComparison {
  const MonthComparison({
    required this.month,
    required this.previousMonth,
    required this.items,
  });

  /// Primer día del mes consultado.
  final DateTime month;

  /// Primer día del mes anterior.
  final DateTime previousMonth;

  /// Variaciones en el orden del gasto del mes, de mayor a menor.
  final List<CategoryVariation> items;

  /// Sin categorías comparables: el mes anterior no tiene gastos en común.
  bool get isEmpty => items.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is MonthComparison &&
      other.month == month &&
      other.previousMonth == previousMonth &&
      _listEquals(other.items, items);

  @override
  int get hashCode => Object.hash(month, previousMonth, Object.hashAll(items));

  @override
  String toString() => 'MonthComparison($month, ${items.length} categorías)';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Variación porcentual redondeada de [previous] a [current].
/// [previous] debe ser mayor que cero.
int percentChange({required int current, required int previous}) {
  return ((current - previous) * 100 / previous).round();
}

/// Variaciones de las categorías de [current] (en su orden) frente a
/// [previous]. Omite las categorías sin gasto en el mes anterior, porque su
/// variación no se puede calcular.
List<CategoryVariation> compareSpending({
  required List<CategorySpending> current,
  required Map<String, int> previous,
}) {
  return [
    for (final spending in current)
      if ((previous[spending.categoryId] ?? 0) > 0)
        CategoryVariation(
          categoryId: spending.categoryId,
          currentAmount: spending.amount,
          previousAmount: previous[spending.categoryId]!,
          percentChange: percentChange(
            current: spending.amount,
            previous: previous[spending.categoryId]!,
          ),
        ),
  ];
}
