import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';
import 'package:mislukas/features/movements/domain/entities/receipt_suggestion.dart';
import 'package:mislukas/features/movements/domain/entities/recognized_receipt.dart';
import 'package:mislukas/features/movements/domain/receipt/receipt_parser.dart';

void main() {
  const parser = ReceiptParser();
  final today = DateTime(2026, 10, 18);

  ReceiptSuggestion parse(String text) =>
      parser.parse(RecognizedReceipt.fromText(text), today: today);

  group('Recibos completos', () {
    test(
      'supermercado: TOTAL A PAGAR sobre subtotal, IVA, efectivo y cambio',
      () {
        final result = parse('''
ALMACENES EXITO S.A.
NIT 890.900.608-9
EXITO AV. EL DORADO
CL 26 # 68C-61 BOGOTA
FACTURA ELECTRONICA DE VENTA No. FE 123456
FECHA: 17/10/2026 HORA: 18:42
LECHE LARGA VIDA X2      8.900
PAN TAJADO               4.500
HUEVOS X30              19.800
ACEITE 900ML            12.400
POLLO PECHUGAS          23.800
ARROZ X5KG              18.000
SUBTOTAL                73.445
IVA 19%                 13.955
TOTAL A PAGAR          \$87.400
EFECTIVO              \$100.000
CAMBIO                 \$12.600
TOTAL ITEMS: 6
RESOLUCION DIAN 18764000001 DEL 2025/01/15 VIGENCIA 24 MESES
GRACIAS POR SU COMPRA
''');
        expect(result.status, ReceiptScanStatus.complete);
        expect(result.total, 87400);
        expect(result.merchant, 'Éxito');
        expect(result.category, DefaultCategory.mercado);
        expect(result.date, DateTime(2026, 10, 17));
      },
    );

    test('tienda de descuento: TOTAL con \$ y sin decimales', () {
      final result = parse('''
TIENDAS D1
KOBA COLOMBIA S.A.S.
NIT 900.276.962-1
16-10-26 10:15
AZUCAR 1KG          3.950
GALLETAS            2.990
TOTAL              \$ 6.940
TARJETA DEBITO **** 4521
''');
      expect(result.total, 6940);
      expect(result.merchant, 'D1');
      expect(result.category, DefaultCategory.mercado);
      expect(result.date, DateTime(2026, 10, 16));
    });

    test('restaurante: total con propina sobre el total sin propina', () {
      final result = parse('''
RESTAURANTE LA CAZUELA S.A.S.
NIT 901.234.567-8
CRA 7 # 45-10 BOGOTA
MESA 4   MESERO: ANDRES
FECHA 12/10/2026
2 BANDEJA PAISA       64.000
2 LIMONADA            12.000
SUBTOTAL              70.370
IMPOCONSUMO 8%         5.630
TOTAL                 76.000
PROPINA VOLUNTARIA 10% 7.600
TOTAL A PAGAR         83.600
''');
      expect(result.total, 83600);
      expect(result.merchant, 'Restaurante la Cazuela');
      expect(result.category, DefaultCategory.restaurantes);
      expect(result.date, DateTime(2026, 10, 12));
    });

    test('restaurante: la propina sola no es el total', () {
      final result = parse('''
FRISBY
SUBTOTAL 45.000
TOTAL 45.000
PROPINA SUGERIDA 4.500
''');
      expect(result.total, 45000);
      expect(result.category, DefaultCategory.restaurantes);
    });

    test('droguería: valor con ,00 y fecha con puntos', () {
      final result = parse('''
DROGUERIAS CRUZ VERDE
NIT 800.149.695-1
FECHA 05.10.2026
ACETAMINOFEN 500MG   12.400,00
VITAMINA C           75.000,00
VALOR TOTAL          87.400,00
''');
      expect(result.total, 87400);
      expect(result.merchant, 'Cruz Verde');
      expect(result.category, DefaultCategory.otros);
      expect(result.date, DateTime(2026, 10, 5));
    });

    test('gasolina: VALOR A PAGAR, galones y categoría Transporte', () {
      final result = parse('''
EDS LA ESPERANZA
ORGANIZACION TERPEL S.A.
NIT 830.095.213-0
FECHA: 2026-10-14 07:30
PRODUCTO: GASOLINA CORRIENTE
GALONES 8,532
PRECIO/GALON 16.140
VALOR A PAGAR \$137.700
''');
      expect(result.total, 137700);
      expect(result.merchant, 'Terpel');
      expect(result.category, DefaultCategory.transporte);
      expect(result.date, DateTime(2026, 10, 14));
    });

    test('factura con base gravable y TOTAL IVA', () {
      final result = parse('''
FERRETERIA EL TORNILLO
NIT 79.555.123-4
17 OCT 2026
BASE GRAVABLE 42.017
TOTAL IVA 7.983
TOTAL 50.000
''');
      expect(result.total, 50000);
      expect(result.merchant, 'Ferreteria el Tornillo');
      expect(result.category, isNull);
      expect(result.date, DateTime(2026, 10, 17));
    });

    test('servicio público: ignora la fecha límite y el periodo', () {
      final result = parse('''
EPM
EMPRESAS PUBLICAS DE MEDELLIN E.S.P.
PERIODO FACTURADO 01/09/2026 - 30/09/2026
FECHA DE EXPEDICION 03/10/2026
PAGO OPORTUNO 20/10/2026
FECHA LIMITE DE PAGO 25/10/2026
ENERGIA 98.430
ACUEDUCTO 45.210
TOTAL A PAGAR 143.640
''');
      expect(result.total, 143640);
      expect(result.merchant, 'EPM');
      expect(result.category, DefaultCategory.servicios);
      expect(result.date, DateTime(2026, 10, 3));
    });

    test('café: categoría Ocio y valor pegado a la palabra', () {
      final result = parse('''
JUAN VALDEZ CAFE
TIQUETE POS 0045
CAPUCCINO 9.900
TOTAL\$9.900
''');
      expect(result.total, 9900);
      expect(result.merchant, 'Juan Valdez');
      expect(result.category, DefaultCategory.ocio);
    });
  });

  group('Lecturas imperfectas', () {
    test('O leída en lugar de cero', () {
      final result = parse('''
MINIMERCADO LA 14
TOTAL: \$ 87.4OO
''');
      expect(result.total, 87400);
      expect(result.category, DefaultCategory.mercado);
    });

    test('el valor está en la fila siguiente', () {
      final result = parse('''
PANADERIA EL TRIGAL
TOTAL A PAGAR
\$ 15.300
''');
      expect(result.total, 15300);
      expect(result.category, DefaultCategory.restaurantes);
    });

    test('total en dos columnas: se une por la ubicación', () {
      const lines = [
        RecognizedLine(
          'TIENDA DON PEPE',
          box: ReceiptBox(left: 40, top: 10, right: 300, bottom: 40),
        ),
        RecognizedLine(
          'SUBTOTAL',
          box: ReceiptBox(left: 20, top: 200, right: 140, bottom: 225),
        ),
        RecognizedLine(
          'TOTAL',
          box: ReceiptBox(left: 20, top: 240, right: 110, bottom: 266),
        ),
        // ML Kit entrega la columna de valores en otro bloque.
        RecognizedLine(
          '40.000',
          box: ReceiptBox(left: 260, top: 202, right: 340, bottom: 226),
        ),
        RecognizedLine(
          '\$47.600',
          box: ReceiptBox(left: 250, top: 243, right: 340, bottom: 268),
        ),
      ];
      final result = parser.parse(const RecognizedReceipt(lines), today: today);
      expect(result.total, 47600);
      expect(
        result.totalBox,
        const ReceiptBox(left: 20, top: 240, right: 340, bottom: 268),
      );
      expect(result.merchant, 'Tienda Don Pepe');
    });

    test('sin total legible: estado parcial y total vacío', () {
      final result = parse('''
SUPERMERCADO LA ECONOMIA
ARROZ 3.200
LECHE 4.100
T0T4L ..... ilegible
''');
      expect(result.status, ReceiptScanStatus.partial);
      expect(result.total, isNull);
      expect(result.merchant, 'Supermercado la Economia');
      expect(result.category, DefaultCategory.mercado);
      expect(result.date, today);
    });

    test('sin palabra clave no propone el valor más alto', () {
      final result = parse('''
ARROZ 3.200
EFECTIVO 50.000
''');
      expect(result.total, isNull);
    });

    test('texto vacío: estado vacío y fecha de hoy', () {
      final result = parser.parse(RecognizedReceipt.empty, today: today);
      expect(result.status, ReceiptScanStatus.empty);
      expect(result.total, isNull);
      expect(result.merchant, isNull);
      expect(result.category, isNull);
      expect(result.date, today);
    });

    test('solo espacios cuenta como vacío', () {
      expect(parse('  \n \n').status, ReceiptScanStatus.empty);
    });
  });

  group('Facturas de servicios y otras frases del total', () {
    test('comprobante de luz: VALOR PAGADO sobre tarifa, consumo y saldos', () {
      final result = parse('''
AIR-E S.A.S. E.S.P.
COMPROBANTE DE PAGO
FECHA DE PAGO 15/10/2026
Valor kWh            \$ 812
Valor consumo        \$ 97.440
Subsidio             \$ -24.360
Contribucion         \$ 12.350
Saldo anterior       \$ 140.200
VALOR PAGADO         \$ 85.430
''');
      expect(result.status, ReceiptScanStatus.complete);
      expect(result.total, 85430);
      expect(result.merchant, 'Air-e');
      expect(result.category, DefaultCategory.servicios);
      expect(result.date, DateTime(2026, 10, 15));
    });

    test('servicio público: TOTAL A PAGAR sobre el pago con recargo', () {
      final result = parse('''
GASES DEL CARIBE S.A. E.S.P.
FECHA DE EXPEDICION 02/10/2026
GAS NATURAL          58.900
TOTAL A PAGAR        64.300
PAGO CON RECARGO     71.850
VALOR A PAGAR CON RECARGO 71.850
INTERESES DE MORA    1.200
''');
      expect(result.total, 64300);
      expect(result.merchant, 'Gases del Caribe');
      expect(result.category, DefaultCategory.servicios);
    });

    test('IMPORTE como única frase', () {
      final result = parse('''
PAPELERIA LA ESTRELLA
FOTOCOPIAS 3.000
IMPORTE \$ 3.000
''');
      expect(result.status, ReceiptScanStatus.complete);
      expect(result.total, 3000);
    });

    test('MONTO como única frase', () {
      expect(parse('LAVANDERIA AZUL\nMONTO: 24.500').total, 24500);
    });

    test('solo VALOR UNITARIO: sin total', () {
      final result = parse('''
FERRETERIA CENTRAL
VALOR UNITARIO 4.500
''');
      expect(result.status, ReceiptScanStatus.partial);
      expect(result.total, isNull);
    });

    test('solo SALDO ANTERIOR: sin total', () {
      final result = parse('''
ESSA
SALDO ANTERIOR \$ 210.000
''');
      expect(result.status, ReceiptScanStatus.partial);
      expect(result.total, isNull);
      expect(result.category, DefaultCategory.servicios);
    });

    test('OCR con ruido: VAL0R PAGAD0 y espacios extra', () {
      expect(parse('CENS\nVAL0R    PAGAD0   \$ 85.43O').total, 85430);
    });

    test('frases del total, sin tildes ni mayúsculas', () {
      String row(String phrase) => normalizeReceiptText(phrase);
      expect(totalPriority(row('Valor pagado')), 0);
      expect(totalPriority(row('Total pagado')), 0);
      expect(totalPriority(row('Saldo pagado')), 0);
      expect(totalPriority(row('Monto pagado')), 0);
      expect(totalPriority(row('Valor del pago')), 0);
      expect(totalPriority(row('Valor pago')), 0);
      expect(totalPriority(row('Pago total')), 0);
      expect(totalPriority(row('Total a cancelar')), 0);
      expect(totalPriority(row('Valor a cancelar')), 0);
      expect(totalPriority(row('Pague este valor')), 0);
      expect(totalPriority(row('Total pago oportuno')), 0);
      expect(totalPriority(row('Pago oportuno')), 0);
      expect(totalPriority(row('Total factura')), 1);
      expect(totalPriority(row('Valor factura')), 1);
      expect(totalPriority(row('Total facturado')), 1);
      expect(totalPriority(row('Valor total factura')), 1);
      expect(totalPriority(row('Importe total')), 1);
      expect(totalPriority(row('Monto total')), 1);
      expect(totalPriority(row('Importe')), 1);
      expect(totalPriority(row('Monto')), 1);
      expect(totalPriority(row('Total')), 2);
    });

    test('VALOR y SALDO solos no son palabras clave', () {
      expect(totalPriority('VALOR 12.000'), isNull);
      expect(totalPriority('SALDO 12.000'), isNull);
    });

    test('exclusiones de facturas de servicios', () {
      for (final phrase in [
        'VALOR UNITARIO',
        'VALOR KWH',
        'VALOR CONSUMO',
        'VALOR SUBSIDIO',
        'TOTAL CONTRIBUCION',
        'VALOR IVA',
        'VALOR MORA',
        'TOTAL INTERES DE MORA',
        'TOTAL INTERESES DE MORA',
        'TOTAL RECARGO',
        'PAGO CON RECARGO',
        'TOTAL A PAGAR CON RECARGO',
        'TOTAL SALDO ANTERIOR',
        'SALDO PENDIENTE',
        'SALDO A FAVOR',
        'PAGO MINIMO',
        'VALOR CUOTA',
        'TOTAL ABONO',
      ]) {
        expect(totalPriority(phrase), isNull, reason: phrase);
      }
    });
  });

  group('Recibo sobre otro papel', () {
    // Una línea de ML Kit a la altura [row] (cada fila mide 30 px). El recibo
    // va de x = 20 a 300; el papel de fondo, de x = 340 a 640.
    RecognizedLine receipt(String text, int row, {double right = 300}) =>
        RecognizedLine(
          text,
          box: ReceiptBox(
            left: 20,
            top: row * 40.0,
            right: right,
            bottom: row * 40.0 + 30,
          ),
        );
    RecognizedLine background(String text, int row, {double left = 340}) =>
        RecognizedLine(
          text,
          box: ReceiptBox(
            left: left,
            top: row * 40.0 + 2,
            right: 640,
            bottom: row * 40.0 + 32,
          ),
        );

    test('CENS: VALOR PAGADO con CUOTA y SALDO del papel de fondo', () {
      final lines = [
        receipt('CENS S.A. E.S.P.', 0),
        background('CREDITO DE LIBRANZA', 0),
        receipt('NIT 890.500.514-9', 1),
        receipt('COMPROBANTE DE PAGO', 2),
        background('CUOTA 3 DE 12', 2),
        receipt('CLIENTE: MARTA LUCIA PEÑA ROJAS', 3),
        receipt('DIR: CL 9 # 4-25 BARRIO LA PLAYA', 4),
        background('VALOR CUOTA \$ 250.000', 4),
        receipt('FECHA VCTO: 05/10/2026', 5),
        background('PAGUE HASTA 08/10/2026', 5),
        receipt('FECHA PAGO: 10/10/2026', 6),
        background('HASTA 15/10/2026', 6),
        receipt('SALDO ACTUAL: 116,736', 7),
        background('SALDO CAPITAL \$ 2.300.000', 7),
        receipt('VALOR PAGADO: \$116,736', 8),
        background('CUOTA MENSUAL \$ 250.000', 8),
        receipt('GRACIAS POR SU PAGO', 9),
        background('SALDO EN MORA \$ 0', 9),
      ];
      final result = parser.parse(RecognizedReceipt(lines), today: today);
      expect(result.status, ReceiptScanStatus.complete);
      expect(result.total, 116736);
      expect(result.totalBox, lines[14].box);
      expect(result.merchant, 'Cens');
      expect(result.category, DefaultCategory.servicios);
      expect(result.date, DateTime(2026, 10, 10));
    });

    test('el monto en otra línea de la misma fila, antes del fondo', () {
      final lines = [
        receipt('CENS', 0),
        receipt('VALOR PAGADO :', 1, right: 180),
        RecognizedLine(
          '\$ 116,736',
          box: ReceiptBox(left: 200, top: 41, right: 300, bottom: 71),
        ),
        background('CUOTA MENSUAL \$ 250.000', 1),
      ];
      final result = parser.parse(RecognizedReceipt(lines), today: today);
      expect(result.total, 116736);
      expect(
        result.totalBox,
        const ReceiptBox(left: 20, top: 40, right: 300, bottom: 71),
      );
    });

    test('el monto en la fila siguiente, con texto de fondo al lado', () {
      final lines = [
        receipt('CENS', 0),
        receipt('VALOR PAGADO', 1),
        background('SALDO ANTERIOR \$ 90.000', 1),
        receipt('\$ 116,736', 2),
        background('CUOTA \$ 250.000', 2),
      ];
      final result = parser.parse(RecognizedReceipt(lines), today: today);
      expect(result.total, 116736);
    });

    test('un monto con texto a la derecha de la palabra clave no se toma', () {
      final lines = [
        receipt('CENS', 0),
        receipt('VALOR PAGADO', 1, right: 180),
        background('CUOTA MENSUAL \$ 250.000', 1),
      ];
      final result = parser.parse(RecognizedReceipt(lines), today: today);
      expect(result.total, isNull);
    });

    test('puntuación pegada a la palabra clave', () {
      expect(parse('CENS\nVALOR PAGADO:\$116,736').total, 116736);
      expect(parse('CENS\nVALOR PAGADO :\$ 116,736').total, 116736);
      expect(parse('CENS\nVALOR PAGADO.\$116.736').total, 116736);
    });

    test('SALDO ACTUAL sola no es el total', () {
      final result = parse('CENS\nSALDO ACTUAL: 116,736');
      expect(result.status, ReceiptScanStatus.partial);
      expect(result.total, isNull);
    });
  });

  group('Fechas', () {
    DateTime dateOf(String line) => parse('TIENDA\n$line\nTOTAL 1.000').date;

    test('formatos reconocidos', () {
      expect(dateOf('17/10/2026'), DateTime(2026, 10, 17));
      expect(dateOf('7/9/2026'), DateTime(2026, 9, 7));
      expect(dateOf('17-10-26'), DateTime(2026, 10, 17));
      expect(dateOf('17.10.2026'), DateTime(2026, 10, 17));
      expect(dateOf('2026-10-17'), DateTime(2026, 10, 17));
      expect(dateOf('2026/10/17'), DateTime(2026, 10, 17));
      expect(dateOf('17 OCT 2026'), DateTime(2026, 10, 17));
      expect(dateOf('17-oct-26'), DateTime(2026, 10, 17));
      expect(dateOf('Fecha: 3 de septiembre de 2026'), DateTime(2026, 9, 3));
    });

    test('una fecha futura se reemplaza por hoy', () {
      expect(dateOf('FECHA 19/10/2026'), today);
      expect(dateOf('01/01/2027'), today);
    });

    test('una fecha inexistente o muy antigua se reemplaza por hoy', () {
      expect(dateOf('31/02/2026'), today);
      expect(dateOf('15/10/1998'), today);
    });

    test('prefiere la fila con FECHA y salta la resolución DIAN', () {
      final result = parse('''
COMERCIO
RESOLUCION DIAN 1876 DEL 15/01/2025
CAJA 2  11/10/2026
FECHA 10/10/2026
TOTAL 5.000
''');
      expect(result.date, DateTime(2026, 10, 10));
    });

    test('la fecha y la hora no se toman como montos', () {
      final result = parse('''
COMERCIO
TOTAL 17/10/2026 18:42 \$ 12.500
''');
      expect(result.total, 12500);
    });
  });

  group('Montos', () {
    test('formatos colombianos', () {
      expect(parseAmount('87.400'), 87400);
      expect(parseAmount('87,400'), 87400);
      expect(parseAmount('87400'), 87400);
      expect(parseAmount('87.400,00'), 87400);
      expect(parseAmount('87400.00'), 87400);
      expect(parseAmount('87 400'), 87400);
      expect(parseAmount('1.250.000'), 1250000);
    });

    test('fuera de rango', () {
      expect(parseAmount('0'), isNull);
      expect(parseAmount('0,00'), isNull);
      expect(parseAmount('3001234567'), isNull);
    });

    test('ignora NIT, porcentajes y tarjetas', () {
      expect(extractAmounts('NIT 890.900.608-9'), isEmpty);
      expect(extractAmounts('IVA 19%'), isEmpty);
      expect(extractAmounts('TARJETA **** 4521'), isEmpty);
      expect(extractAmounts('TOTAL \$ 87.400 COP'), [87400]);
    });
  });

  group('Comercio', () {
    test('salta NIT, direcciones y encabezados de factura', () {
      expect(isMerchantCandidate('NIT 900.123.456-7'), isFalse);
      expect(isMerchantCandidate('CRA 7 # 45-10'), isFalse);
      expect(isMerchantCandidate('CL 26 68C-61'), isFalse);
      expect(isMerchantCandidate('FACTURA ELECTRONICA DE VENTA'), isFalse);
      expect(isMerchantCandidate('TEL 6012345678'), isFalse);
      expect(isMerchantCandidate('RESTAURANTE LA CAZUELA'), isTrue);
    });

    test('limpia la razón social y respeta un nombre con minúsculas', () {
      expect(
        cleanMerchantName('PANADERIA SAN JORGE S.A.S.'),
        'Panaderia San Jorge',
      );
      expect(cleanMerchantName('Distribuidora Ltda'), 'Distribuidora');
      expect(cleanMerchantName('Café de la Esquina'), 'Café de la Esquina');
    });

    test('el comercio se recorta al largo máximo', () {
      final result = parse('${'A' * 300}\nTOTAL 1.000');
      expect(result.merchant!.length, lessThanOrEqualTo(200));
    });
  });
}
