import '../../../core/utils/clock.dart';
import '../../movements/domain/entities/month_summary.dart';
import '../../movements/domain/entities/movement.dart';
import '../../movements/domain/repositories/movement_repository.dart';

/// Máximo de meses completos que se promedian para el ahorro (RF-38).
const int savingsAverageMonths = 3;

/// Resultado del ahorro promedio mensual (RF-38 y RF-39).
sealed class SavingsAverage {
  const SavingsAverage();
}

/// Ningún mes completo del período tiene movimientos: no hay datos
/// suficientes ("Necesitamos al menos un mes de datos…", docs/05 §5.3).
class SavingsAverageInsufficientData extends SavingsAverage {
  const SavingsAverageInsufficientData();

  @override
  bool operator ==(Object other) => other is SavingsAverageInsufficientData;

  @override
  int get hashCode => (SavingsAverageInsufficientData).hashCode;
}

/// Promedio calculado con los meses de [months]. [isSaving] es false si es
/// cero o negativo.
class SavingsAverageResult extends SavingsAverage {
  SavingsAverageResult({required List<DateTime> months, required this.amount})
    : assert(months.isNotEmpty),
      months = List.unmodifiable(months);

  /// Primer día de cada mes promediado, del más antiguo al más reciente.
  final List<DateTime> months;

  /// Promedio mensual de ingresos − gastos, en pesos (división entera).
  final int amount;

  /// Primer mes del período real ("Junio" en "Junio – Agosto 2026").
  DateTime get from => months.first;

  /// Último mes del período real; igual a [from] si se usó un solo mes.
  DateTime get to => months.last;

  bool get isSaving => amount > 0;

  @override
  bool operator ==(Object other) =>
      other is SavingsAverageResult &&
      other.amount == amount &&
      other.months.length == months.length &&
      Iterable.generate(months.length)
          .every((i) => other.months[i] == months[i]);

  @override
  int get hashCode => Object.hash(amount, Object.hashAll(months));

  @override
  String toString() => 'SavingsAverageResult(${months.length} meses)';
}

/// Promedio de ingresos − gastos de los meses de [months] (primer día de cada
/// uno, del más antiguo al más reciente) que tengan movimientos. Los meses sin
/// movimientos no cuentan; si ninguno tiene, no hay datos suficientes.
SavingsAverage calculateSavingsAverage({
  required List<DateTime> months,
  required Iterable<Movement> movements,
}) {
  final summaries = [
    for (final month in months)
      summarizeMonth(
        month: month,
        movements: movements.where(
          (m) => m.date.year == month.year && m.date.month == month.month,
        ),
      ),
  ].where((summary) => !summary.isEmpty).toList();

  if (summaries.isEmpty) return const SavingsAverageInsufficientData();

  final total = summaries.fold<int>(0, (sum, s) => sum + s.available);
  return SavingsAverageResult(
    months: [for (final summary in summaries) summary.month],
    amount: total ~/ summaries.length,
  );
}

/// Ahorro promedio de los últimos 3 meses completos antes del mes actual que
/// tengan movimientos: el 22 de septiembre de 2026 revisa junio, julio y
/// agosto, y promedia los que tengan datos (al menos uno).
class GetSavingsAverage {
  const GetSavingsAverage({required this._movements, required this._clock});

  final MovementRepository _movements;
  final Clock _clock;

  Future<SavingsAverage> call() async {
    final months = _clock.lastCompleteMonths(savingsAverageMonths);
    final movements = await _movements.getBetween(
      months.first,
      nextMonthStart(months.last),
    );
    return calculateSavingsAverage(months: months, movements: movements);
  }

  /// Igual que [call], pero se actualiza cuando cambian los movimientos de
  /// esos meses. Solo emite si el resultado cambia.
  Stream<SavingsAverage> watch() {
    final months = _clock.lastCompleteMonths(savingsAverageMonths);
    return _movements
        .watchBetween(months.first, nextMonthStart(months.last))
        .map(
          (movements) =>
              calculateSavingsAverage(months: months, movements: movements),
        )
        .distinct();
  }
}
