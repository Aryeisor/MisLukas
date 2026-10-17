import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/utils/clock.dart';
import 'package:mislukas/core/utils/utils_providers.dart';

void main() {
  test('sin fecha simulada el reloj es el del sistema', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(debugMonthOffsetProvider), 0);
    expect(container.read(clockProvider), isA<SystemClock>());
  });

  test('en desarrollo, adelantar un mes corre el reloj y se puede volver', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final realMonth = container.read(clockProvider).currentMonth();

    container.read(debugMonthOffsetProvider.notifier).advanceMonth();
    final clock = container.read(clockProvider);
    expect(clock, isA<MonthShiftedClock>());
    expect(clock.currentMonth(), nextMonthStart(realMonth));

    container.read(debugMonthOffsetProvider.notifier).reset();
    expect(container.read(clockProvider), isA<SystemClock>());
  });
}
