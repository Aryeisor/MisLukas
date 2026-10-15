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
