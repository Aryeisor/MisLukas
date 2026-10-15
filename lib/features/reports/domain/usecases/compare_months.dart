import '../../../../core/utils/clock.dart';
import '../../../movements/domain/repositories/movement_repository.dart';
import '../entities/category_spending.dart';
import '../entities/month_comparison.dart';

/// Variación del gasto por categoría de un mes (por defecto, el actual) frente
/// al mes anterior (RF-35).
class CompareMonths {
  const CompareMonths({required this._movements, required this._clock});

  final MovementRepository _movements;
  final Clock _clock;

  Stream<MonthComparison> call({DateTime? month}) {
    final start = monthStart(month ?? _clock.now());
    final previous = previousMonthStart(start);
    // Una sola consulta para los dos meses.
    return _movements.watchBetween(previous, nextMonthStart(start)).map((list) {
      final current = calculateCategorySpending(
        list.where((m) => !m.date.isBefore(start)),
      );
      final before = expensesByCategory(
        list.where((m) => m.date.isBefore(start)),
      );
      return MonthComparison(
        month: start,
        previousMonth: previous,
        items: compareSpending(current: current, previous: before),
      );
    });
  }
}
