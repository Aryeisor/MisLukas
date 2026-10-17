/// Reloj de la aplicación. Dart puro.
///
/// Los casos de uso piden "hoy" y "mes actual" a un [Clock] en lugar de llamar
/// a `DateTime.now()`, para poder fijar la fecha en las pruebas.
library;

abstract interface class Clock {
  /// Momento actual en hora local.
  DateTime now();
}

/// Reloj del sistema.
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// Reloj detenido en una fecha fija (pruebas).
class FixedClock implements Clock {
  const FixedClock(this._now);

  final DateTime _now;

  @override
  DateTime now() => _now;
}

/// Reloj corrido [months] meses respecto a [base], para simular otro mes en
/// modo desarrollo. Conserva el día y la hora; si el mes destino es más corto,
/// usa su último día (31 de enero + 1 mes = 28 o 29 de febrero).
class MonthShiftedClock implements Clock {
  const MonthShiftedClock(this._base, this.months);

  final Clock _base;
  final int months;

  @override
  DateTime now() => shiftMonths(_base.now(), months);
}

/// [date] corrido [months] meses, con el día recortado al último del mes.
DateTime shiftMonths(DateTime date, int months) {
  final target = DateTime(date.year, date.month + months);
  final lastDay = DateTime(target.year, target.month + 1, 0).day;
  return DateTime(
    target.year,
    target.month,
    date.day > lastDay ? lastDay : date.day,
    date.hour,
    date.minute,
    date.second,
    date.millisecond,
    date.microsecond,
  );
}

extension ClockDates on Clock {
  /// Fecha de hoy, sin hora.
  DateTime today() => dateOnly(now());

  /// Primer día del mes actual.
  DateTime currentMonth() => monthStart(now());

  /// Primer día de cada uno de los últimos [count] meses completos, del más
  /// antiguo al más reciente. El 22 de septiembre de 2026 con count 3 da
  /// junio, julio y agosto de 2026.
  List<DateTime> lastCompleteMonths(int count) {
    final current = currentMonth();
    return [
      for (var i = count; i >= 1; i--)
        DateTime(current.year, current.month - i),
    ];
  }
}

/// [date] sin hora.
DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// Primer día del mes de [date].
DateTime monthStart(DateTime date) => DateTime(date.year, date.month);

/// Primer día del mes siguiente al de [date].
DateTime nextMonthStart(DateTime date) => DateTime(date.year, date.month + 1);

/// Primer día del mes anterior al de [date].
DateTime previousMonthStart(DateTime date) =>
    DateTime(date.year, date.month - 1);
