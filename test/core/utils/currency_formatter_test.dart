import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter.format', () {
    test('formatea cero', () {
      expect(CurrencyFormatter.format(0), '\$0');
    });

    test('usa punto como separador de miles', () {
      expect(CurrencyFormatter.format(87400), '\$87.400');
    });

    test('formatea millones', () {
      expect(CurrencyFormatter.format(1874320), '\$1.874.320');
    });

    test('muestra el valor absoluto de un monto negativo', () {
      expect(CurrencyFormatter.format(-87400), '\$87.400');
    });
  });

  group('CurrencyFormatter.signed', () {
    test('antepone - a los gastos', () {
      expect(CurrencyFormatter.signed(87400, isIncome: false), '-\$87.400');
    });

    test('antepone + a los ingresos', () {
      expect(
        CurrencyFormatter.signed(3800000, isIncome: true),
        '+\$3.800.000',
      );
    });
  });
}
