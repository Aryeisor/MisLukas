import '../../../movements/domain/entities/movement.dart';
import 'budget.dart';

/// Umbrales de alerta de presupuesto, en porcentaje (RF-30 y RF-31).
enum BudgetAlertThreshold {
  warning(75),
  exceeded(100);

  const BudgetAlertThreshold(this.percent);

  final int percent;
}

/// Presupuesto que llegó a un umbral de alerta. Inmutable, con igualdad por
/// valor.
class BudgetAlert {
  const BudgetAlert({
    required this.categoryId,
    required this.month,
    required this.limitAmount,
    required this.spent,
    required this.percent,
    required this.threshold,
  });

  final String categoryId;
  final DateTime month;
  final int limitAmount;
  final int spent;

  /// Porcentaje entero del límite usado (división entera).
  final int percent;

  /// Umbral más alto alcanzado.
  final BudgetAlertThreshold threshold;

  /// Lo que queda del límite; negativo si se superó.
  int get remaining => limitAmount - spent;

  @override
  bool operator ==(Object other) =>
      other is BudgetAlert &&
      other.categoryId == categoryId &&
      other.month == month &&
      other.limitAmount == limitAmount &&
      other.spent == spent &&
      other.percent == percent &&
      other.threshold == threshold;

  @override
  int get hashCode =>
      Object.hash(categoryId, month, limitAmount, spent, percent, threshold);

  @override
  String toString() => 'BudgetAlert($categoryId, ${threshold.name})';
}

/// Porcentaje entero de [limit] usado por [spent]. División entera: 74,9%
/// cuenta como 74% y no dispara la alerta del 75%.
int budgetUsagePercent({required int spent, required int limit}) {
  return limit > 0 ? spent * 100 ~/ limit : 0;
}

/// Alertas de [budgets] según los gastos de [movements], que deben ser del mismo
/// mes. Devuelve solo los que llegan al 75%, del mayor porcentaje al menor.
List<BudgetAlert> evaluateBudgetAlerts({
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

  final alerts = <BudgetAlert>[];
  for (final budget in budgets) {
    final spent = spentByCategory[budget.categoryId] ?? 0;
    final percent = budgetUsagePercent(spent: spent, limit: budget.limitAmount);
    final threshold = percent >= BudgetAlertThreshold.exceeded.percent
        ? BudgetAlertThreshold.exceeded
        : percent >= BudgetAlertThreshold.warning.percent
        ? BudgetAlertThreshold.warning
        : null;
    if (threshold == null) continue;
    alerts.add(
      BudgetAlert(
        categoryId: budget.categoryId,
        month: budget.month,
        limitAmount: budget.limitAmount,
        spent: spent,
        percent: percent,
        threshold: threshold,
      ),
    );
  }
  alerts.sort((a, b) => b.percent.compareTo(a.percent));
  return alerts;
}
