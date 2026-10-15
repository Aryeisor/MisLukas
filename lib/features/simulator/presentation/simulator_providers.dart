import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/utils_providers.dart';
import '../../movements/data/movements_providers.dart';
import '../domain/get_savings_average.dart';

// Casos de uso del Simulador. La feature no tiene capa de datos propia: lee
// los movimientos del repositorio de movements.

final getSavingsAverageProvider = Provider<GetSavingsAverage>(
  (ref) => GetSavingsAverage(
    movements: ref.watch(movementRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);
