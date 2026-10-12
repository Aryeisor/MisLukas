import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/utils/date_formatter.dart';

void main() {
  final today = DateTime(2026, 9, 22);

  test('monthYear escribe el mes completo en español', () {
    expect(DateLabels.monthYear(today), 'Septiembre 2026');
    expect(DateLabels.monthYear(DateTime(2026, 1, 5)), 'Enero 2026');
  });

  test('monthName y shortMonthYear', () {
    expect(DateLabels.monthName(today), 'septiembre');
    expect(DateLabels.shortMonthYear(today), 'Sep 2026');
    expect(DateLabels.shortMonthYear(DateTime(2026, 8)), 'Ago 2026');
  });

  test('monthRange con el mismo año y con años distintos', () {
    expect(
      DateLabels.monthRange(DateTime(2026, 6), DateTime(2026, 8)),
      'Junio – Agosto 2026',
    );
    expect(
      DateLabels.monthRange(DateTime(2025, 11), DateTime(2026, 1)),
      'Noviembre 2025 – Enero 2026',
    );
  });

  group('relativeDay', () {
    test('hoy y ayer', () {
      expect(DateLabels.relativeDay(DateTime(2026, 9, 22, 18), today), 'Hoy');
      expect(DateLabels.relativeDay(DateTime(2026, 9, 21), today), 'Ayer');
    });

    test('otros días con mes abreviado', () {
      expect(DateLabels.relativeDay(DateTime(2026, 9, 1), today), 'Sep 1');
      expect(DateLabels.relativeDay(DateTime(2026, 8, 30), today), 'Ago 30');
    });
  });

  test('isSameMonth compara mes y año', () {
    expect(DateLabels.isSameMonth(DateTime(2026, 9, 1), today), isTrue);
    expect(DateLabels.isSameMonth(DateTime(2026, 8, 31), today), isFalse);
    expect(DateLabels.isSameMonth(DateTime(2025, 9, 22), today), isFalse);
  });
}
