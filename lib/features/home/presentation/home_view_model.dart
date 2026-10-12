import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/demo/demo_data.dart';
import '../../../core/utils/date_formatter.dart';
import 'home_state.dart';

/// Umbral de alerta de presupuesto (CLAUDE.md: alertas al 75% y al 100%).
const int budgetAlertThreshold = 75;

/// Cantidad de movimientos en "Últimos movimientos".
const int latestMovementsLimit = 5;

final homeViewModelProvider = NotifierProvider<HomeViewModel, HomeState>(
  HomeViewModel.new,
);

/// ViewModel de Inicio. Lee de la demo en memoria; en la Fase 4 leerá de los
/// casos de uso sin cambiar la vista.
class HomeViewModel extends Notifier<HomeState> {
  @override
  HomeState build() {
    return buildHomeState(
      movements: ref.watch(demoMovementsProvider),
      today: ref.watch(demoTodayProvider),
      userName: demoUserName,
      unlistedIncome: demoUnlistedIncome,
      unlistedExpenses: demoUnlistedExpenses,
      budgets: demoBudgets,
    );
  }
}

// Funciones puras con los cálculos de Inicio.

/// Totales de ingresos y gastos del mes de [today].
({int income, int expenses}) calculateMonthTotals({
  required List<DemoMovement> movements,
  required DateTime today,
  int unlistedIncome = 0,
  int unlistedExpenses = 0,
}) {
  var income = unlistedIncome;
  var expenses = unlistedExpenses;
  for (final movement in movements) {
    if (!DateLabels.isSameMonth(movement.date, today)) continue;
    if (movement.isIncome) {
      income += movement.amount;
    } else {
      expenses += movement.amount;
    }
  }
  return (income: income, expenses: expenses);
}

/// Uso de un presupuesto en el mes de [today].
({int spent, int percent, int remaining}) calculateBudgetUsage({
  required DemoBudget budget,
  required List<DemoMovement> movements,
  required DateTime today,
}) {
  var spent = budget.unlistedSpent;
  for (final movement in movements) {
    if (movement.category == budget.category &&
        DateLabels.isSameMonth(movement.date, today)) {
      spent += movement.amount;
    }
  }
  // División entera: 74,9% cuenta como 74% y no dispara la alerta del 75%.
  final percent = budget.limit > 0 ? spent * 100 ~/ budget.limit : 0;
  return (spent: spent, percent: percent, remaining: budget.limit - spent);
}

/// Alerta del presupuesto con mayor porcentaje, si alguno llega al umbral.
BudgetAlert? selectBudgetAlert({
  required List<DemoBudget> budgets,
  required List<DemoMovement> movements,
  required DateTime today,
}) {
  BudgetAlert? alert;
  for (final budget in budgets) {
    final usage = calculateBudgetUsage(
      budget: budget,
      movements: movements,
      today: today,
    );
    if (usage.percent < budgetAlertThreshold) continue;
    if (alert == null || usage.percent > alert.percent) {
      alert = BudgetAlert(
        category: budget.category,
        percent: usage.percent,
        remaining: usage.remaining,
      );
    }
  }
  return alert;
}

/// Estado de Inicio a partir de los movimientos.
HomeState buildHomeState({
  required List<DemoMovement> movements,
  required DateTime today,
  required String userName,
  int unlistedIncome = 0,
  int unlistedExpenses = 0,
  List<DemoBudget> budgets = const [],
}) {
  final monthLabel = DateLabels.monthYear(today);
  final monthMovements = movements
      .where((m) => DateLabels.isSameMonth(m.date, today))
      .toList();

  if (monthMovements.isEmpty) {
    return HomeEmpty(monthLabel: monthLabel, userName: userName);
  }

  final totals = calculateMonthTotals(
    movements: monthMovements,
    today: today,
    unlistedIncome: unlistedIncome,
    unlistedExpenses: unlistedExpenses,
  );

  return HomeData(
    monthLabel: monthLabel,
    userName: userName,
    income: totals.income,
    expenses: totals.expenses,
    budgetAlert: selectBudgetAlert(
      budgets: budgets,
      movements: monthMovements,
      today: today,
    ),
    latestMovements: [
      for (final movement in monthMovements.take(latestMovementsLimit))
        HomeMovementItem(
          id: movement.id,
          title: movement.title,
          category: movement.category,
          dateLabel: DateLabels.relativeDay(movement.date, today),
          amount: movement.amount,
        ),
    ],
  );
}
