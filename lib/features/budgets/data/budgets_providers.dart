import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/notifications/local_notifications.dart';
import '../../../core/security/external_activity_tracker.dart';
import '../../../core/utils/utils_providers.dart';
import '../../movements/data/movements_providers.dart';
import '../domain/repositories/budget_alert_log.dart';
import '../domain/repositories/budget_repository.dart';
import '../domain/repositories/category_repository.dart';
import '../domain/repositories/notification_services.dart';
import '../domain/usecases/carry_over_budgets.dart';
import '../domain/usecases/evaluate_budget_alerts.dart';
import '../domain/usecases/notify_budget_alerts.dart';
import '../domain/usecases/remove_budget.dart';
import '../domain/usecases/set_budget.dart';
import '../domain/usecases/watch_budget_overview.dart';
import 'device_notification_services.dart';
import 'drift_budget_alert_log.dart';
import 'drift_budget_repository.dart';
import 'drift_category_repository.dart';
import 'drift_notification_settings_repository.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => DriftCategoryRepository(ref.watch(appDatabaseProvider)),
);

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => DriftBudgetRepository(ref.watch(appDatabaseProvider)),
);

final setBudgetProvider = Provider<SetBudget>(
  (ref) => SetBudget(
    budgets: ref.watch(budgetRepositoryProvider),
    categories: ref.watch(categoryRepositoryProvider),
    clock: ref.watch(clockProvider),
    ids: ref.watch(idGeneratorProvider),
  ),
);

final evaluateBudgetAlertsProvider = Provider<EvaluateBudgetAlerts>(
  (ref) => EvaluateBudgetAlerts(
    budgets: ref.watch(budgetRepositoryProvider),
    movements: ref.watch(movementRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

final watchBudgetAlertsProvider = Provider<WatchBudgetAlerts>(
  (ref) => WatchBudgetAlerts(
    budgets: ref.watch(budgetRepositoryProvider),
    movements: ref.watch(movementRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

final removeBudgetProvider = Provider<RemoveBudget>(
  (ref) => RemoveBudget(
    budgets: ref.watch(budgetRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

final carryOverBudgetsProvider = Provider<CarryOverBudgets>(
  (ref) => CarryOverBudgets(
    budgets: ref.watch(budgetRepositoryProvider),
    clock: ref.watch(clockProvider),
    ids: ref.watch(idGeneratorProvider),
  ),
);

final watchBudgetOverviewProvider = Provider<WatchBudgetOverview>(
  (ref) => WatchBudgetOverview(
    budgets: ref.watch(budgetRepositoryProvider),
    movements: ref.watch(movementRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

final budgetAlertLogProvider = Provider<BudgetAlertLog>(
  (ref) => DriftBudgetAlertLog(ref.watch(appDatabaseProvider)),
);

final notificationSettingsRepositoryProvider =
    Provider<NotificationSettingsRepository>(
      (ref) =>
          DriftNotificationSettingsRepository(ref.watch(appDatabaseProvider)),
    );

final notificationPermissionProvider = Provider<NotificationPermissionService>(
  (ref) => PermissionHandlerNotificationPermission(
    ref.read(externalActivityTrackerProvider),
  ),
);

final budgetAlertNotifierProvider = Provider<BudgetAlertNotifier>(
  (ref) => LocalBudgetAlertNotifier(ref.watch(localNotificationsProvider)),
);

final notifyBudgetAlertsProvider = Provider<NotifyBudgetAlerts>(
  (ref) => NotifyBudgetAlerts(
    evaluate: ref.watch(evaluateBudgetAlertsProvider),
    log: ref.watch(budgetAlertLogProvider),
    categories: ref.watch(categoryRepositoryProvider),
    settings: ref.watch(notificationSettingsRepositoryProvider),
    permission: ref.watch(notificationPermissionProvider),
    notifier: ref.watch(budgetAlertNotifierProvider),
    clock: ref.watch(clockProvider),
  ),
);
