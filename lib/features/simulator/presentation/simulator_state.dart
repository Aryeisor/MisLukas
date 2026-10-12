import '../domain/savings_calculator.dart';

/// Estado del Simulador de ahorro.
sealed class SimulatorState {
  const SimulatorState({required this.periodLabel});

  /// Últimos 3 meses completos: "Junio – Agosto 2026".
  final String periodLabel;
}

/// No hay datos suficientes para calcular el ahorro promedio (RF-39).
class SimulatorNoData extends SimulatorState {
  const SimulatorNoData({required super.periodLabel});
}

/// El ahorro promedio es cero o negativo: no hay nada que proyectar (RF-39).
class SimulatorNotSaving extends SimulatorState {
  const SimulatorNotSaving({required super.periodLabel});
}

class SimulatorData extends SimulatorState {
  const SimulatorData({
    required super.periodLabel,
    required this.averageSavings,
    required this.years,
    required this.monthlyContribution,
    required this.minContribution,
    required this.contributionStep,
    required this.projection,
    required this.yearlySeries,
    required this.boostedProjection,
  });

  /// Ahorro promedio mensual real del usuario.
  final int averageSavings;

  /// Horizonte de tiempo en años.
  final int years;
  final int monthlyContribution;
  final int minContribution;
  final int contributionStep;

  /// Resultado a [years] años con el aporte actual.
  final SavingsProjection projection;

  /// Serie del año 1 al año [years] para el gráfico.
  final List<SavingsProjection> yearlySeries;

  /// Resultado con [contributionStep] más al mes.
  final SavingsProjection boostedProjection;

  /// Cuánto más se acumula con interés al aportar [contributionStep] más.
  int get boostDifference =>
      boostedProjection.withInterest - projection.withInterest;

  bool get canDecrease => monthlyContribution - contributionStep >= minContribution;
}
