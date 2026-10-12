/// Textos de fechas en español para la interfaz.
abstract final class DateLabels {
  static const List<String> _months = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  static const List<String> _shortMonths = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];

  /// Mes y año: "Septiembre 2026".
  static String monthYear(DateTime date) =>
      '${_months[date.month - 1]} ${date.year}';

  /// Nombre del mes en minúscula: "septiembre".
  static String monthName(DateTime date) =>
      _months[date.month - 1].toLowerCase();

  /// Mes abreviado y año: "Sep 2026".
  static String shortMonthYear(DateTime date) =>
      '${_shortMonths[date.month - 1]} ${date.year}';

  /// Rango de meses: "Junio – Agosto 2026", o "Noviembre 2025 – Enero 2026"
  /// si los años son distintos.
  static String monthRange(DateTime from, DateTime to) {
    if (from.year == to.year) {
      return '${_months[from.month - 1]} – ${monthYear(to)}';
    }
    return '${monthYear(from)} – ${monthYear(to)}';
  }

  /// "Hoy", "Ayer" o mes abreviado y día ("Sep 1"), relativo a [today].
  static String relativeDay(DateTime date, DateTime today) {
    final day = DateTime(date.year, date.month, date.day);
    final reference = DateTime(today.year, today.month, today.day);
    final difference = reference.difference(day).inDays;

    if (difference == 0) return 'Hoy';
    if (difference == 1) return 'Ayer';
    return '${_shortMonths[date.month - 1]} ${date.day}';
  }

  /// Indica si [date] cae en el mismo mes y año que [reference].
  static bool isSameMonth(DateTime date, DateTime reference) =>
      date.year == reference.year && date.month == reference.month;
}
