import '../../../../core/utils/clock.dart';
import '../../../../core/utils/streams.dart';
import '../../../movements/domain/entities/movement.dart';
import '../../../movements/domain/repositories/movement_repository.dart';
import '../entities/budget.dart';
import '../entities/budget_alert.dart';
import '../entities/default_categories.dart';
import '../repositories/budget_repository.dart';

/// Presupuesto de una categoría de gasto en el mes: su límite (si tiene), lo
/// gastado y el porcentaje usado. Inmutable.
class BudgetLine {
  const BudgetLine({
    required this.categoryId,
    required this.budget,
    required this.spent,
  });

  final String categoryId;

  /// Null si la categoría no tiene presupuesto este mes.
  final Budget? budget;
  final int spent;

  /// Porcentaje entero del límite usado; 0 sin presupuesto.
  int get percent => budget == null
      ? 0
      : budgetUsagePercent(spent: spent, limit: budget!.limitAmount);

  /// Lo que queda del límite; negativo si se superó. 0 sin presupuesto.
  int get remaining => budget == null ? 0 : budget!.limitAmount - spent;

  @override
  bool operator ==(Object other) =>
      other is BudgetLine &&
      other.categoryId == categoryId &&
      other.budget == budget &&
      other.spent == spent;

  @override
  int get hashCode => Object.hash(categoryId, budget, spent);

  @override
  String toString() => 'BudgetLine($categoryId)';
}

/// Categorías de gasto predeterminadas, en el orden en que se muestran.
final List<String> expenseCategoryIds = [
  for (final category in DefaultCategory.values)
    if (category.type == MovementType.expense) category.id,
];

/// Presupuestos del mes (por defecto, el actual) para cada categoría de gasto,
/// con lo gastado (RF-52). Se actualiza al cambiar los movimientos o los
/// presupuestos.
class WatchBudgetOverview {
  const WatchBudgetOverview({
    required this._budgets,
    required this._movements,
    required this._clock,
  });

  final BudgetRepository _budgets;
  final MovementRepository _movements;
  final Clock _clock;

  Stream<List<BudgetLine>> call({DateTime? month}) {
    final start = monthStart(month ?? _clock.now());
    return combineLatest(
      _budgets.watchForMonth(start),
      _movements.watchBetween(start, nextMonthStart(start)),
    ).map((pair) => budgetLines(budgets: pair.$1, movements: pair.$2));
  }
}

/// Una línea por categoría de gasto, con su presupuesto de [budgets] y lo
/// gastado en [movements] (que deben ser del mismo mes).
List<BudgetLine> budgetLines({
  required Iterable<Budget> budgets,
  required Iterable<Movement> movements,
}) {
  final spentByCategory = <String, int>{};
  for (final movement in movements) {
    if (movement.isIncome || movement.isDeleted) continue;
    spentByCategory.update(
      movement.categoryId,
      (value) => value + movement.amount,
      ifAbsent: () => movement.amount,
    );
  }
  final budgetByCategory = {
    for (final budget in budgets) budget.categoryId: budget,
  };
  return [
    for (final categoryId in expenseCategoryIds)
      BudgetLine(
        categoryId: categoryId,
        budget: budgetByCategory[categoryId],
        spent: spentByCategory[categoryId] ?? 0,
      ),
  ];
}
