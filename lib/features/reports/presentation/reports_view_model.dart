import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_messages.dart';
import '../../../core/theme/category_mapping.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/utils_providers.dart';
import '../domain/entities/category_spending.dart';
import '../domain/entities/month_comparison.dart' as domain;
import 'reports_providers.dart';
import 'reports_state.dart';

/// Gastos por categoría del mes actual.
final reportsSpendingProvider =
    StreamProvider.autoDispose<List<CategorySpending>>(
      (ref) => ref.watch(watchCategorySpendingProvider).call(),
    );

/// Variación frente al mes anterior.
final reportsComparisonProvider =
    StreamProvider.autoDispose<domain.MonthComparison>(
      (ref) => ref.watch(compareMonthsProvider).call(),
    );

final reportsViewModelProvider =
    NotifierProvider<ReportsViewModel, ReportsState>(ReportsViewModel.new);

/// ViewModel de Reportes. Combina los streams de los casos de uso: se
/// actualiza solo al guardar, editar o eliminar un movimiento.
class ReportsViewModel extends Notifier<ReportsState> {
  @override
  ReportsState build() {
    final spending = ref.watch(reportsSpendingProvider);
    final comparison = ref.watch(reportsComparisonProvider);

    // El error va primero: al reintentar, el valor sigue en error y cargando.
    if (spending.hasError || comparison.hasError) {
      return const ReportsError(dataLoadErrorMessage);
    }
    final spendingValue = spending.value;
    final comparisonValue = comparison.value;
    if (spendingValue == null || comparisonValue == null) {
      return const ReportsLoading();
    }

    return buildReportsState(
      month: ref.watch(clockProvider).currentMonth(),
      spending: spendingValue,
      comparison: comparisonValue,
    );
  }
}

/// Variaciones de presentación: la barra de cada categoría es proporcional a
/// la mayor variación absoluta.
List<CategoryVariation> toVariations(List<domain.CategoryVariation> items) {
  final maxChange = items
      .map((item) => item.percentChange.abs())
      .fold<int>(0, (max, v) => v > max ? v : max);
  return [
    for (final item in items)
      CategoryVariation(
        category: categoryKindForId(item.categoryId),
        percentChange: item.percentChange,
        fraction: maxChange == 0 ? 0 : item.percentChange.abs() / maxChange,
      ),
  ];
}

/// Estado de Reportes para [month] (primer día del mes).
ReportsState buildReportsState({
  required DateTime month,
  required List<CategorySpending> spending,
  required domain.MonthComparison comparison,
}) {
  if (spending.isEmpty) {
    return ReportsEmpty(
      monthLabel: DateLabels.monthYear(month),
      monthName: DateLabels.monthName(month),
    );
  }

  return ReportsData(
    monthLabel: DateLabels.monthYear(month),
    monthName: DateLabels.monthName(month),
    shortMonthLabel: DateLabels.shortMonthYear(month),
    total: spending.fold<int>(0, (sum, s) => sum + s.amount),
    shares: [
      for (final share in spending)
        CategoryShare(
          category: categoryKindForId(share.categoryId),
          amount: share.amount,
          percent: share.percent,
        ),
    ],
    comparison: comparison.isEmpty
        ? null
        : MonthComparison(
            previousMonthLabel: DateLabels.monthYear(previousMonthStart(month))
                .toLowerCase(),
            items: toVariations(comparison.items),
          ),
  );
}
