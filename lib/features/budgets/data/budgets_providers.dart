import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/utils/utils_providers.dart';
import '../../movements/data/movements_providers.dart';
import '../domain/repositories/budget_repository.dart';
import '../domain/repositories/category_repository.dart';
import '../domain/usecases/carry_over_budgets.dart';
import '../domain/usecases/evaluate_budget_alerts.dart';
import '../domain/usecases/remove_budget.dart';
import '../domain/usecases/set_budget.dart';
import '../domain/usecases/watch_budget_overview.dart';
import 'drift_budget_repository.dart';
import 'drift_category_repository.dart';

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
