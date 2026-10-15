import '../../../../core/errors/domain_exception.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../core/utils/validators.dart';
import '../../../movements/domain/entities/movement.dart';
import '../entities/budget.dart';
import '../repositories/budget_repository.dart';
import '../repositories/category_repository.dart';

/// Define el límite mensual de gasto de una categoría (RF-28). Si ya existe un
/// presupuesto para esa categoría y mes, lo actualiza.
class SetBudget {
  const SetBudget({
    required this._budgets,
    required this._categories,
    required this._clock,
    required this._ids,
  });

  final BudgetRepository _budgets;
  final CategoryRepository _categories;
  final Clock _clock;
  final IdGenerator _ids;

  /// [month] puede ser cualquier día del mes; por defecto, el mes actual.
  /// Lanza [DomainException] si el límite o la categoría no son válidos.
  Future<Budget> call({
    required String categoryId,
    required int? limitAmount,
    DateTime? month,
  }) async {
    if (!isValidAmount(limitAmount)) {
      throw const DomainException(DomainError.invalidAmount);
    }
    final category = await _categories.findById(categoryId);
    if (category == null) {
      throw const DomainException(DomainError.categoryNotFound);
    }
    if (category.type != MovementType.expense) {
      throw const DomainException(DomainError.invalidCategory);
    }

    return _budgets.save(
      Budget(
        id: _ids.newId(),
        categoryId: categoryId,
        month: monthStart(month ?? _clock.now()),
        limitAmount: limitAmount!,
      ),
      at: _clock.now(),
    );
  }
}
