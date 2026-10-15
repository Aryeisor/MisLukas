import '../../../movements/domain/entities/movement.dart';

/// Gasto de una categoría en un mes y su porcentaje del total. Inmutable, con
/// igualdad por valor.
class CategorySpending {
  const CategorySpending({
    required this.categoryId,
    required this.amount,
    required this.percent,
  });

  final String categoryId;
  final int amount;

  /// Porcentaje entero; los de todas las categorías del mes suman 100.
  final int percent;

  @override
  bool operator ==(Object other) =>
      other is CategorySpending &&
      other.categoryId == categoryId &&
      other.amount == amount &&
      other.percent == percent;

  @override
  int get hashCode => Object.hash(categoryId, amount, percent);

  @override
  String toString() => 'CategorySpending($categoryId, $percent%)';
}

/// Total de gastos por categoría de [movements]. Ignora ingresos y eliminados,
/// y omite las categorías en cero.
Map<String, int> expensesByCategory(Iterable<Movement> movements) {
  final totals = <String, int>{};
  for (final movement in movements) {
    if (movement.isIncome || movement.isDeleted) continue;
    totals.update(
      movement.categoryId,
      (value) => value + movement.amount,
      ifAbsent: () => movement.amount,
    );
  }
  totals.removeWhere((_, amount) => amount <= 0);
  return totals;
}

/// Porcentaje entero de cada monto de [amounts] sobre su suma, en el mismo
/// orden. Usa el método del resto mayor: se toma la parte entera de cada
/// porcentaje y los puntos que faltan para 100 se reparten entre los restos más
/// grandes (en empate, el mayor monto y luego el primero), así la suma es
/// exactamente 100. Si la suma es cero, todos son cero.
List<int> distributePercentages(List<int> amounts) {
  final total = amounts.fold<int>(0, (sum, v) => sum + v);
  if (total <= 0) return List.filled(amounts.length, 0);

  final percents = [for (final a in amounts) a * 100 ~/ total];
  final remainders = [for (final a in amounts) a * 100 % total];
  var missing = 100 - percents.fold<int>(0, (sum, p) => sum + p);

  final byRemainder = List.generate(amounts.length, (i) => i)
    ..sort((a, b) {
      final byRest = remainders[b].compareTo(remainders[a]);
      if (byRest != 0) return byRest;
      final byAmount = amounts[b].compareTo(amounts[a]);
      return byAmount != 0 ? byAmount : a.compareTo(b);
    });
  for (final index in byRemainder) {
    if (missing <= 0) break;
    percents[index]++;
    missing--;
  }
  return percents;
}

/// Gastos por categoría de [movements] con su porcentaje, de mayor a menor
/// gasto. En empate de monto, ordena por identificador para ser estable.
List<CategorySpending> calculateCategorySpending(Iterable<Movement> movements) {
  final entries = expensesByCategory(movements).entries.toList()
    ..sort((a, b) {
      final byAmount = b.value.compareTo(a.value);
      return byAmount != 0 ? byAmount : a.key.compareTo(b.key);
    });
  final percents = distributePercentages([for (final e in entries) e.value]);
  return [
    for (var i = 0; i < entries.length; i++)
      CategorySpending(
        categoryId: entries[i].key,
        amount: entries[i].value,
        percent: percents[i],
      ),
  ];
}
