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
