import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_messages.dart';
import '../../../core/sync/sync_status.dart';
import '../../../core/theme/category_mapping.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/utils_providers.dart';
import '../../auth/data/auth_providers.dart';
import '../../budgets/data/budgets_providers.dart';
import '../../budgets/domain/entities/budget_alert.dart' as domain;
import '../../movements/data/movements_providers.dart';
import '../../movements/domain/entities/month_summary.dart';
import '../../movements/domain/entities/movement.dart';
import 'home_state.dart';

/// Resumen del mes actual.
final homeMonthSummaryProvider = StreamProvider.autoDispose<MonthSummary>(
  (ref) => ref.watch(watchMonthSummaryProvider).call(),
);

/// Últimos movimientos, del más reciente al más antiguo.
final homeRecentMovementsProvider = StreamProvider.autoDispose<List<Movement>>(
  (ref) => ref.watch(watchRecentMovementsProvider).call(),
);

/// Alertas de presupuesto del mes actual, de mayor a menor porcentaje.
final homeBudgetAlertsProvider =
    StreamProvider.autoDispose<List<domain.BudgetAlert>>(
      (ref) => ref.watch(watchBudgetAlertsProvider).call(),
    );

final homeViewModelProvider = NotifierProvider<HomeViewModel, HomeState>(
  HomeViewModel.new,
);

/// ViewModel de Inicio. Combina los streams de los casos de uso: se actualiza
/// solo al guardar, editar o eliminar un movimiento.
class HomeViewModel extends Notifier<HomeState> {
  @override
  HomeState build() {
    final summary = ref.watch(homeMonthSummaryProvider);
    final recent = ref.watch(homeRecentMovementsProvider);
    final alerts = ref.watch(homeBudgetAlertsProvider);

    // El error va primero: al reintentar, el valor sigue en error y cargando.
    if (summary.hasError || recent.hasError || alerts.hasError) {
      return const HomeError(dataLoadErrorMessage);
    }
    final summaryValue = summary.value;
    final recentValue = recent.value;
    final alertsValue = alerts.value;
    if (summaryValue == null || recentValue == null || alertsValue == null) {
      return const HomeLoading();
    }

    return buildHomeState(
      summary: summaryValue,
      recent: recentValue,
      alerts: alertsValue,
      today: ref.watch(clockProvider).today(),
      userName: ref.watch(currentUserProvider)?.firstName ?? '',
    );
  }
}

/// Estado de Inicio a partir de los datos de los casos de uso.
HomeState buildHomeState({
  required MonthSummary summary,
  required List<Movement> recent,
  required List<domain.BudgetAlert> alerts,
  required DateTime today,
  required String userName,
}) {
  final monthLabel = DateLabels.monthYear(today);
  if (summary.isEmpty) {
    return HomeEmpty(monthLabel: monthLabel, userName: userName);
  }

  final alert = alerts.isEmpty ? null : alerts.first;
  return HomeData(
    monthLabel: monthLabel,
    userName: userName,
    income: summary.income,
    expenses: summary.expenses,
    budgetAlert: alert == null
        ? null
        : BudgetAlert(
            category: categoryKindForId(alert.categoryId),
            percent: alert.percent,
            remaining: alert.remaining,
          ),
    latestMovements: [
      for (final movement in recent)
        HomeMovementItem(
          id: movement.id,
          title: movement.note ?? movement.description,
          category: categoryKindForId(movement.categoryId),
          dateLabel: DateLabels.relativeDay(movement.date, today),
          amount: movement.amount,
          isPendingSync: movement.syncStatus != SyncStatus.synced,
        ),
    ],
  );
}
