import '../../../../core/errors/domain_exception.dart';
import '../../../../core/utils/clock.dart';
import '../repositories/budget_repository.dart';

/// Quita un presupuesto con borrado lógico (RF-52). En el mes ya no vuelve a
/// copiarse (RF-53).
class RemoveBudget {
  const RemoveBudget({required this._budgets, required this._clock});

  final BudgetRepository _budgets;
  final Clock _clock;

  /// Lanza [DomainException] si el presupuesto no existe o ya fue quitado.
  Future<void> call(String id) async {
    final current = await _budgets.findById(id);
    if (current == null) {
      throw const DomainException(DomainError.budgetNotFound);
    }
    await _budgets.remove(id, at: _clock.now());
  }
}
