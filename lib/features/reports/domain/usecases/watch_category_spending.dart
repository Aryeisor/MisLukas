import '../../../../core/utils/clock.dart';
import '../../../movements/domain/repositories/movement_repository.dart';
import '../entities/category_spending.dart';

/// Gastos por categoría de un mes (por defecto, el actual), de mayor a menor,
/// con porcentajes que suman 100 (RF-34).
class WatchCategorySpending {
  const WatchCategorySpending({required this._movements, required this._clock});

  final MovementRepository _movements;
  final Clock _clock;

  Stream<List<CategorySpending>> call({DateTime? month}) {
    final start = monthStart(month ?? _clock.now());
    return _movements
        .watchBetween(start, nextMonthStart(start))
        .map(calculateCategorySpending);
  }
}
