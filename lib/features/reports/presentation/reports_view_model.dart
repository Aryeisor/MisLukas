import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/demo/demo_data.dart';
import '../../../core/theme/category_style.dart';
import '../../../core/utils/date_formatter.dart';
import 'reports_state.dart';

final reportsViewModelProvider =
    NotifierProvider<ReportsViewModel, ReportsState>(ReportsViewModel.new);

/// ViewModel de Reportes. Lee de la demo en memoria; en la Fase 4 leerá de los
/// casos de uso sin cambiar la vista.
class ReportsViewModel extends Notifier<ReportsState> {
  @override
  ReportsState build() {
    return buildReportsState(
      movements: ref.watch(demoMovementsProvider),
      today: ref.watch(demoTodayProvider),
      unlistedByMonth: ref.watch(demoUnlistedExpensesByMonthProvider),
    );
  }
}

// Funciones puras con los cálculos de Reportes.

/// Gastos por categoría del mes de [month]: los no listados más los
/// movimientos de gasto de la lista. Omite categorías en cero.
Map<CategoryKind, int> expensesByCategory({
  required DateTime month,
  required List<DemoMovement> movements,
  Map<DateTime, Map<CategoryKind, int>> unlistedByMonth = const {},
}) {
  final totals = <CategoryKind, int>{
    ...?unlistedByMonth[DateTime(month.year, month.month)],
  };
  for (final movement in movements) {
    if (movement.isIncome || !DateLabels.isSameMonth(movement.date, month)) {
      continue;
    }
    totals.update(
      movement.category,
      (value) => value + movement.amount,
      ifAbsent: () => movement.amount,
    );
  }
  totals.removeWhere((_, amount) => amount <= 0);
  return totals;
}

/// Porcentaje de cada categoría, ordenado de mayor a menor gasto.
///
/// Usa el método del resto mayor: se toma la parte entera de cada porcentaje y
/// los puntos que faltan para 100 se reparten entre los restos más grandes,
/// así la suma es exactamente 100.
List<CategoryShare> distributePercentages(Map<CategoryKind, int> amounts) {
  final total = amounts.values.fold<int>(0, (sum, v) => sum + v);
  if (total <= 0) return const [];

  final entries = amounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final percents = [for (final e in entries) e.value * 100 ~/ total];
  final remainders = [for (final e in entries) e.value * 100 % total];

  var missing = 100 - percents.fold<int>(0, (sum, p) => sum + p);
  // Índices por resto descendente; en empate, gana la de mayor gasto.
  final byRemainder = List.generate(entries.length, (i) => i)
    ..sort((a, b) {
      final byRest = remainders[b].compareTo(remainders[a]);
      return byRest != 0 ? byRest : entries[b].value.compareTo(entries[a].value);
    });
  for (final index in byRemainder) {
    if (missing <= 0) break;
    percents[index]++;
    missing--;
  }

  return [
    for (var i = 0; i < entries.length; i++)
      CategoryShare(
        category: entries[i].key,
        amount: entries[i].value,
        percent: percents[i],
      ),
  ];
}

/// Variación porcentual redondeada de [previous] a [current].
/// [previous] debe ser mayor que cero.
int percentChange({required int current, required int previous}) {
  return ((current - previous) * 100 / previous).round();
}

/// Variaciones por categoría en el orden de [order]. Omite las categorías sin
/// gasto en el mes anterior, porque su variación no se puede calcular.
List<CategoryVariation> calculateVariations({
  required Map<CategoryKind, int> current,
  required Map<CategoryKind, int> previous,
  required List<CategoryKind> order,
}) {
  final changes = <(CategoryKind, int)>[
    for (final category in order)
      if ((previous[category] ?? 0) > 0)
        (
          category,
          percentChange(
            current: current[category] ?? 0,
            previous: previous[category]!,
          ),
        ),
  ];
  final maxChange = changes
      .map((c) => c.$2.abs())
      .fold<int>(0, (max, v) => v > max ? v : max);

  return [
    for (final (category, change) in changes)
      CategoryVariation(
        category: category,
        percentChange: change,
        fraction: maxChange == 0 ? 0 : change.abs() / maxChange,
      ),
  ];
}

/// Estado de Reportes para el mes de [today].
ReportsState buildReportsState({
  required List<DemoMovement> movements,
  required DateTime today,
  Map<DateTime, Map<CategoryKind, int>> unlistedByMonth = const {},
}) {
  final month = DateTime(today.year, today.month);
  final previousMonth = DateTime(today.year, today.month - 1);

  final current = expensesByCategory(
    month: month,
    movements: movements,
    unlistedByMonth: unlistedByMonth,
  );
  if (current.isEmpty) {
    return ReportsEmpty(
      monthLabel: DateLabels.monthYear(month),
      monthName: DateLabels.monthName(month),
    );
  }

  final shares = distributePercentages(current);
  final previous = expensesByCategory(
    month: previousMonth,
    movements: movements,
    unlistedByMonth: unlistedByMonth,
  );
  final variations = calculateVariations(
    current: current,
    previous: previous,
    order: [for (final share in shares) share.category],
  );

  return ReportsData(
    monthLabel: DateLabels.monthYear(month),
    monthName: DateLabels.monthName(month),
    shortMonthLabel: DateLabels.shortMonthYear(month),
    total: current.values.fold<int>(0, (sum, v) => sum + v),
    shares: shares,
    comparison: variations.isEmpty
        ? null
        : MonthComparison(
            previousMonthLabel: DateLabels.monthYear(previousMonth).toLowerCase(),
            items: variations,
          ),
  );
}
