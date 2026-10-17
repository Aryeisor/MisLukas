import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/utils/utils_providers.dart';
import '../../budgets/data/budgets_providers.dart';
import '../domain/repositories/movement_repository.dart';
import '../domain/usecases/delete_movement.dart';
import '../domain/usecases/get_movement.dart';
import '../domain/usecases/register_income.dart';
import '../domain/usecases/register_movement.dart';
import '../domain/usecases/update_movement.dart';
import '../domain/usecases/watch_month_summary.dart';
import '../domain/usecases/watch_movement_history.dart';
import '../domain/usecases/watch_recent_movements.dart';
import 'drift_movement_repository.dart';

final movementRepositoryProvider = Provider<MovementRepository>(
  (ref) => DriftMovementRepository(ref.watch(appDatabaseProvider)),
);

final registerMovementProvider = Provider<RegisterMovement>(
  (ref) => RegisterMovement(
    movements: ref.watch(movementRepositoryProvider),
    categories: ref.watch(categoryRepositoryProvider),
    clock: ref.watch(clockProvider),
    ids: ref.watch(idGeneratorProvider),
  ),
);

final registerIncomeProvider = Provider<RegisterIncome>(
  (ref) => RegisterIncome(ref.watch(registerMovementProvider)),
);

final updateMovementProvider = Provider<UpdateMovement>(
  (ref) => UpdateMovement(
    movements: ref.watch(movementRepositoryProvider),
    categories: ref.watch(categoryRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

final deleteMovementProvider = Provider<DeleteMovement>(
  (ref) => DeleteMovement(
    movements: ref.watch(movementRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

final getMovementProvider = Provider<GetMovement>(
  (ref) => GetMovement(movements: ref.watch(movementRepositoryProvider)),
);

final watchRecentMovementsProvider = Provider<WatchRecentMovements>(
  (ref) =>
      WatchRecentMovements(movements: ref.watch(movementRepositoryProvider)),
);

final watchMovementHistoryProvider = Provider<WatchMovementHistory>(
  (ref) =>
      WatchMovementHistory(movements: ref.watch(movementRepositoryProvider)),
);

final watchMonthSummaryProvider = Provider<WatchMonthSummary>(
  (ref) => WatchMonthSummary(
    movements: ref.watch(movementRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);
