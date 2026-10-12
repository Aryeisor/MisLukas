import 'package:intl/intl.dart';

/// Formatea montos en pesos colombianos: `$1.874.320` (punto de miles, sin decimales).
abstract final class CurrencyFormatter {
  static final NumberFormat _format = NumberFormat('#,##0', 'es_CO');

  /// Valor absoluto del monto con signo de pesos. 1874320 -> "$1.874.320".
  static String format(int amount) => '\$${formatDigits(amount)}';

  /// Valor absoluto del monto sin signo de pesos. 87400 -> "87.400".
  static String formatDigits(int amount) {
    // Se fuerza el punto como separador de miles por si el locale cambia.
    return _format
        .format(amount.abs())
        .replaceAll(_format.symbols.GROUP_SEP, '.');
  }

  /// Monto con signo según el tipo: "+$3.800.000" o "-$87.400".
  static String signed(int amount, {required bool isIncome}) {
    return '${isIncome ? '+' : '-'}${format(amount)}';
  }

  /// Convierte un texto con dígitos y separadores ("$87.400") en int.
  /// Devuelve null si no contiene dígitos.
  static int? parse(String text) {
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? null : int.tryParse(digits);
  }
}
