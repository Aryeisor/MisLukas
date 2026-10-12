import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/demo/demo_data.dart';
import '../../../core/utils/date_formatter.dart';
import '../domain/savings_calculator.dart';
import 'simulator_state.dart';

/// Horizonte de tiempo permitido, en años (RF-40).
const int simulatorMinYears = 1;
const int simulatorMaxYears = 10;
const int simulatorInitialYears = 3;

/// Pasos y mínimo del aporte mensual (RF-42).
const int contributionStep = 50000;
const int minContribution = 50000;

/// Meses completos que se promedian para el ahorro (RF-38).
const int averagedMonths = 3;

final simulatorViewModelProvider =
    NotifierProvider<SimulatorViewModel, SimulatorState>(
      SimulatorViewModel.new,
    );

/// ViewModel del Simulador de ahorro. Lee el ahorro promedio de la demo; en la
/// Fase 4 lo calculará un caso de uso con los movimientos guardados.
class SimulatorViewModel extends Notifier<SimulatorState> {
  @override
  SimulatorState build() {
    final periodLabel = savingsPeriodLabel(ref.watch(demoTodayProvider));
    final average = ref.watch(demoAverageSavingsProvider);

    if (average == null) return SimulatorNoData(periodLabel: periodLabel);
    if (average <= 0) return SimulatorNotSaving(periodLabel: periodLabel);

    return buildSimulatorData(
      periodLabel: periodLabel,
      averageSavings: average,
      years: simulatorInitialYears,
      // El aporte parte del ahorro real y nunca queda por debajo del mínimo.
      monthlyContribution: average < minContribution ? minContribution : average,
    );
  }

  /// Cambia el horizonte, limitado de 1 a 10 años.
  void setYears(int years) {
    final current = state;
    if (current is! SimulatorData) return;
    final clamped = years.clamp(simulatorMinYears, simulatorMaxYears);
    if (clamped == current.years) return;
    state = _rebuild(current, years: clamped);
  }

  void increaseContribution() {
    final current = state;
    if (current is! SimulatorData) return;
    state = _rebuild(
      current,
      monthlyContribution: current.monthlyContribution + contributionStep,
    );
  }

  void decreaseContribution() {
    final current = state;
    if (current is! SimulatorData || !current.canDecrease) return;
    state = _rebuild(
      current,
      monthlyContribution: current.monthlyContribution - contributionStep,
    );
  }

  SimulatorData _rebuild(
    SimulatorData current, {
    int? years,
    int? monthlyContribution,
  }) {
    return buildSimulatorData(
      periodLabel: current.periodLabel,
      averageSavings: current.averageSavings,
      years: years ?? current.years,
      monthlyContribution: monthlyContribution ?? current.monthlyContribution,
    );
  }
}

/// Últimos [averagedMonths] meses completos antes del mes de [today]:
/// el 22 de septiembre de 2026 da "Junio – Agosto 2026".
String savingsPeriodLabel(DateTime today) {
  final last = DateTime(today.year, today.month - 1);
  final first = DateTime(today.year, today.month - averagedMonths);
  return DateLabels.monthRange(first, last);
}

/// Estado con todos los resultados calculados para el horizonte y el aporte.
SimulatorData buildSimulatorData({
  required String periodLabel,
  required int averageSavings,
  required int years,
  required int monthlyContribution,
}) {
  return SimulatorData(
    periodLabel: periodLabel,
    averageSavings: averageSavings,
    years: years,
    monthlyContribution: monthlyContribution,
    minContribution: minContribution,
    contributionStep: contributionStep,
    projection: projectSavings(
      monthlyContribution: monthlyContribution,
      years: years,
    ),
    yearlySeries: projectSavingsByYear(
      monthlyContribution: monthlyContribution,
      years: years,
    ),
    boostedProjection: projectSavings(
      monthlyContribution: monthlyContribution + contributionStep,
      years: years,
    ),
  );
}
