import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/utils_providers.dart';
import '../../movements/data/movements_providers.dart';
import '../domain/usecases/compare_months.dart';
import '../domain/usecases/watch_category_spending.dart';

// Casos de uso de Reportes. La feature no tiene capa de datos propia: lee los
// movimientos del repositorio de movements.

final watchCategorySpendingProvider = Provider<WatchCategorySpending>(
  (ref) => WatchCategorySpending(
    movements: ref.watch(movementRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

final compareMonthsProvider = Provider<CompareMonths>(
  (ref) => CompareMonths(
    movements: ref.watch(movementRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);
