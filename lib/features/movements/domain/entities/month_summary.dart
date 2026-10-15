import 'movement.dart';

/// Totales de un mes. Inmutable, con igualdad por valor.
class MonthSummary {
  const MonthSummary({
    required this.month,
    required this.income,
    required this.expenses,
    required this.movementCount,
  });

  /// Primer día del mes.
  final DateTime month;
  final int income;
  final int expenses;

  /// Movimientos del mes (sin eliminados); cero significa mes vacío.
  final int movementCount;

  /// Disponible del mes = ingresos − gastos.
  int get available => income - expenses;

  bool get isEmpty => movementCount == 0;

  @override
  bool operator ==(Object other) =>
      other is MonthSummary &&
      other.month == month &&
      other.income == income &&
      other.expenses == expenses &&
      other.movementCount == movementCount;

  @override
  int get hashCode => Object.hash(month, income, expenses, movementCount);

  @override
  String toString() => 'MonthSummary($month, $movementCount movimientos)';
}

/// Suma ingresos y gastos de [movements], que deben ser del mes [month].
/// Ignora los eliminados.
MonthSummary summarizeMonth({
  required DateTime month,
  required Iterable<Movement> movements,
}) {
  var income = 0;
  var expenses = 0;
  var count = 0;
  for (final movement in movements) {
    if (movement.isDeleted) continue;
    count++;
    if (movement.isIncome) {
      income += movement.amount;
    } else {
      expenses += movement.amount;
    }
  }
  return MonthSummary(
    month: month,
    income: income,
    expenses: expenses,
    movementCount: count,
  );
}
