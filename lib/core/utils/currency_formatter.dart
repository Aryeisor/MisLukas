import 'package:intl/intl.dart';

/// Formatea montos en pesos colombianos: `$1.874.320` (punto de miles, sin decimales).
abstract final class CurrencyFormatter {
  static final NumberFormat _format = NumberFormat('#,##0', 'es_CO');

  /// Valor absoluto del monto con signo de pesos. 1874320 -> "$1.874.320".
  static String format(int amount) {
    // Se fuerza el punto como separador de miles por si el locale cambia.
    final digits = _format
        .format(amount.abs())
        .replaceAll(_format.symbols.GROUP_SEP, '.');
    return '\$$digits';
  }

  /// Monto con signo según el tipo: "+$3.800.000" o "-$87.400".
  static String signed(int amount, {required bool isIncome}) {
    return '${isIncome ? '+' : '-'}${format(amount)}';
  }
}
