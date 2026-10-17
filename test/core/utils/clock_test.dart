import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/utils/clock.dart';

void main() {
  final clock = FixedClock(DateTime(2026, 9, 22, 18, 45));

  test('hoy y mes actual sin hora', () {
    expect(clock.today(), DateTime(2026, 9, 22));
    expect(clock.currentMonth(), DateTime(2026, 9));
  });

  test('últimos 3 meses completos: junio a agosto de 2026', () {
    expect(clock.lastCompleteMonths(3), [
      DateTime(2026, 6),
      DateTime(2026, 7),
      DateTime(2026, 8),
    ]);
  });

  test('últimos meses completos cruzando el año', () {
    final january = FixedClock(DateTime(2027, 1, 5));
    expect(january.lastCompleteMonths(3), [
      DateTime(2026, 10),
      DateTime(2026, 11),
      DateTime(2026, 12),
    ]);
  });

  test('inicio de mes, mes siguiente y anterior', () {
    expect(monthStart(DateTime(2026, 12, 31, 23)), DateTime(2026, 12));
    expect(nextMonthStart(DateTime(2026, 12, 15)), DateTime(2027, 1));
    expect(previousMonthStart(DateTime(2026, 1, 15)), DateTime(2025, 12));
    expect(dateOnly(DateTime(2026, 9, 22, 10, 30)), DateTime(2026, 9, 22));
  });

  group('MonthShiftedClock (fecha simulada en desarrollo)', () {
    test('corre los meses conservando el día y la hora', () {
      final shifted = MonthShiftedClock(clock, 1);
      expect(shifted.now(), DateTime(2026, 10, 22, 18, 45));
      expect(shifted.currentMonth(), DateTime(2026, 10));
    });

    test('recorta al último día del mes y cambia de año', () {
      expect(shiftMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(shiftMonths(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
      expect(shiftMonths(DateTime(2026, 12, 15), 1), DateTime(2027, 1, 15));
      expect(shiftMonths(DateTime(2026, 9, 22), 0), DateTime(2026, 9, 22));
    });
  });
}
