import '../../../../core/utils/clock.dart';
import '../../../../core/utils/streams.dart';
import '../../../movements/domain/repositories/movement_repository.dart';
import '../entities/budget_alert.dart';
import '../repositories/budget_repository.dart';

/// Revisa qué presupuestos del mes llegaron al 75% o al 100% (RF-30, RF-31).
///
/// Se ejecuta después de registrar un gasto (docs/06 §6.3.1). Solo evalúa:
/// recordar qué alertas ya se notificaron (una por categoría, umbral y mes) le
/// corresponde a las notificaciones de la Fase 6.
class EvaluateBudgetAlerts {
  const EvaluateBudgetAlerts({
    required this._budgets,
    required this._movements,
    required this._clock,
  });

  final BudgetRepository _budgets;
  final MovementRepository _movements;
  final Clock _clock;

  /// Alertas del mes de [month] (por defecto, el actual), de mayor a menor
  /// porcentaje.
  Future<List<BudgetAlert>> call({DateTime? month}) async {
    final start = monthStart(month ?? _clock.now());
    final budgets = await _budgets.getForMonth(start);
    if (budgets.isEmpty) return const [];
    final movements = await _movements.getBetween(start, nextMonthStart(start));
    return evaluateBudgetAlerts(budgets: budgets, movements: movements);
  }
}

/// Igual que [EvaluateBudgetAlerts], pero se actualiza al cambiar los
/// movimientos o los presupuestos (alerta de Inicio).
class WatchBudgetAlerts {
  const WatchBudgetAlerts({
    required this._budgets,
    required this._movements,
    required this._clock,
  });

  final BudgetRepository _budgets;
  final MovementRepository _movements;
  final Clock _clock;

  Stream<List<BudgetAlert>> call({DateTime? month}) {
    final start = monthStart(month ?? _clock.now());
    return combineLatest(
      _budgets.watchForMonth(start),
      _movements.watchBetween(start, nextMonthStart(start)),
    ).map((pair) => evaluateBudgetAlerts(budgets: pair.$1, movements: pair.$2));
  }
}
