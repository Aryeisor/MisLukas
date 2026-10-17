import '../../../../core/utils/clock.dart';
import '../../../../core/utils/id_generator.dart';
import '../entities/budget.dart';
import '../repositories/budget_repository.dart';

/// Continúa los presupuestos en el mes actual (RF-53): si el mes no tiene
/// ninguno, copia los del último mes que tuvo, con ids nuevos y los mismos
/// límites. Abrir la app varias veces en el mes no duplica nada, y un
/// presupuesto quitado en el mes no vuelve.
class CarryOverBudgets {
  const CarryOverBudgets({
    required this._budgets,
    required this._clock,
    required this._ids,
  });

  final BudgetRepository _budgets;
  final Clock _clock;
  final IdGenerator _ids;

  /// Devuelve los presupuestos copiados; vacío si no había nada que copiar.
  Future<List<Budget>> call() {
    final now = _clock.now();
    return _budgets.carryOver(
      month: monthStart(now),
      at: now,
      newId: _ids.newId,
    );
  }
}
