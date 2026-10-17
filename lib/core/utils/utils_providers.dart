import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'clock.dart';
import 'id_generator.dart';

/// Reloj de la app. En pruebas se sobrescribe con un [FixedClock].
///
/// Solo en modo desarrollo, [debugMonthOffsetProvider] puede correrlo meses
/// para simular el cambio de mes. En la versión de publicación `kDebugMode`
/// es una constante falsa y el reloj es siempre el del sistema.
final clockProvider = Provider<Clock>((ref) {
  if (kDebugMode) {
    final offset = ref.watch(debugMonthOffsetProvider);
    if (offset != 0) return MonthShiftedClock(const SystemClock(), offset);
  }
  return const SystemClock();
});

/// Meses que se adelanta el reloj de la app, solo en modo desarrollo. Vive en
/// memoria: al cerrar la app vuelve a la fecha real.
final debugMonthOffsetProvider = NotifierProvider<DebugMonthOffset, int>(
  DebugMonthOffset.new,
);

class DebugMonthOffset extends Notifier<int> {
  @override
  int build() => 0;

  /// Adelanta un mes el "hoy" de la app. No hace nada fuera de desarrollo.
  void advanceMonth() {
    if (kDebugMode) state = state + 1;
  }

  /// Vuelve a la fecha real.
  void reset() => state = 0;
}

/// Generador de identificadores UUID v4.
final idGeneratorProvider = Provider<IdGenerator>(
  (ref) => const UuidIdGenerator(),
);
