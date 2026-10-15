import '../../../../core/utils/clock.dart';
import '../entities/month_summary.dart';
import '../repositories/movement_repository.dart';

/// Ingresos, gastos y disponible de un mes; por defecto, el actual.
class WatchMonthSummary {
  const WatchMonthSummary({required this._movements, required this._clock});

  final MovementRepository _movements;
  final Clock _clock;

  Stream<MonthSummary> call({DateTime? month}) {
    final start = monthStart(month ?? _clock.now());
    return _movements
        .watchBetween(start, nextMonthStart(start))
        .map((list) => summarizeMonth(month: start, movements: list));
  }
}
