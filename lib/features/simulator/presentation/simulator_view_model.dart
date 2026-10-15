import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_messages.dart';
import '../../../core/utils/date_formatter.dart';
import '../domain/get_savings_average.dart';
import '../domain/savings_calculator.dart';
import 'simulator_providers.dart';
import 'simulator_state.dart';

/// Horizonte de tiempo permitido, en años (RF-40).
const int simulatorMinYears = 1;
const int simulatorMaxYears = 10;
const int simulatorInitialYears = 3;

/// Pasos y mínimo del aporte mensual (RF-42).
const int contributionStep = 50000;
const int minContribution = 50000;

final simulatorViewModelProvider =
    NotifierProvider<SimulatorViewModel, SimulatorState>(
      SimulatorViewModel.new,
    );

/// ViewModel del Simulador de ahorro. Toma el ahorro promedio de
/// GetSavingsAverage; el horizonte y el aporte vuelven a sus valores iniciales
/// solo si el promedio cambia.
class SimulatorViewModel extends Notifier<SimulatorState> {
  @override
  SimulatorState build() {
    final average = ref.watch(savingsAverageProvider);

    // El error va primero: al reintentar, el valor sigue en error y cargando.
    if (average.hasError) return const SimulatorError(dataLoadErrorMessage);
    return switch (average.value) {
      null => const SimulatorLoading(),
      SavingsAverageInsufficientData() => const SimulatorNoData(),
      final SavingsAverageResult result when !result.isSaving =>
        SimulatorNotSaving(
          periodLabel: savingsPeriodLabel(result.from, result.to),
        ),
      final SavingsAverageResult result => buildSimulatorData(
        periodLabel: savingsPeriodLabel(result.from, result.to),
        averageSavings: result.amount,
        years: simulatorInitialYears,
        // El aporte parte del ahorro real y nunca queda por debajo del mínimo.
        monthlyContribution: result.amount < minContribution
            ? minContribution
            : result.amount,
      ),
    };
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

/// Meses que realmente se promediaron: "Junio – Agosto 2026", o
/// "Agosto 2026" si fue uno solo.
String savingsPeriodLabel(DateTime from, DateTime to) {
  if (DateLabels.isSameMonth(from, to)) return DateLabels.monthYear(from);
  return DateLabels.monthRange(from, to);
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
