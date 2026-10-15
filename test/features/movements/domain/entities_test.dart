import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/features/budgets/domain/entities/budget.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';
import 'package:mislukas/features/movements/domain/entities/month_summary.dart';
import 'package:mislukas/features/movements/domain/entities/movement.dart';
import 'package:mislukas/features/movements/domain/entities/receipt.dart';
import 'package:mislukas/features/movements/domain/movement_text.dart';

import '../../../helpers/domain_fixtures.dart';

void main() {
  group('igualdad por valor', () {
    test('Movement', () {
      final a = testMovement(id: 'x', amount: 500);
      final b = testMovement(id: 'x', amount: 500);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(testMovement(id: 'x', amount: 501)));
    });

    test('Receipt, Budget y Category', () {
      const receipt = Receipt(id: 'r', movementId: 'm', localPath: 'a.jpg');
      expect(
        receipt,
        const Receipt(id: 'r', movementId: 'm', localPath: 'a.jpg'),
      );
      expect(
        Budget(
          id: 'b',
          categoryId: 'c',
          month: DateTime(2026, 9),
          limitAmount: 1,
        ),
        Budget(
          id: 'b',
          categoryId: 'c',
          month: DateTime(2026, 9),
          limitAmount: 1,
        ),
      );
      expect(
        DefaultCategory.mercado.toCategory(),
        DefaultCategory.mercado.toCategory(),
      );
    });

    test('toString no expone montos ni textos del usuario', () {
      final movement = testMovement(amount: 87400, description: 'Éxito');
      expect(movement.toString(), isNot(contains('87400')));
      expect(movement.toString(), isNot(contains('Éxito')));
    });
  });

  test('copyWith puede borrar la nota', () {
    final movement = testMovement(note: 'algo');
    expect(movement.copyWith(note: () => null).note, isNull);
    expect(movement.copyWith(amount: 2).note, 'algo');
  });

  group('categorías predeterminadas', () {
    test('siete categorías con UUID v4 fijos y únicos', () {
      final uuidV4 = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      final ids = DefaultCategory.values.map((c) => c.id).toSet();
      expect(ids, hasLength(7));
      expect(ids.every(uuidV4.hasMatch), isTrue);
      expect(
        DefaultCategory.mercado.id,
        '2909b516-0ab3-493e-b8e8-90f8ccf28aed',
      );
    });

    test('clave, nombre y tipo', () {
      final ingreso = DefaultCategory.ingreso.toCategory();
      expect(ingreso.key, 'ingreso');
      expect(ingreso.name, 'Ingreso');
      expect(ingreso.type, MovementType.income);
      expect(ingreso.isDefault, isTrue);
      expect(DefaultCategory.otros.type, MovementType.expense);
      expect(
        DefaultCategory.fromId(DefaultCategory.ocio.id),
        DefaultCategory.ocio,
      );
      expect(DefaultCategory.fromId('no-existe'), isNull);
    });
  });

  group('resumen del mes', () {
    test('disponible = ingresos − gastos; ignora eliminados', () {
      final summary = summarizeMonth(
        month: DateTime(2026, 9),
        movements: [
          testMovement(category: DefaultCategory.ingreso, amount: 4250000),
          testMovement(amount: 2375680),
          testMovement(amount: 999, deletedAt: testToday),
        ],
      );
      expect(summary.income, 4250000);
      expect(summary.expenses, 2375680);
      expect(summary.available, 1874320);
      expect(summary.movementCount, 2);
      expect(summary.isEmpty, isFalse);
    });

    test('mes vacío', () {
      final summary = summarizeMonth(month: DateTime(2026, 9), movements: []);
      expect(summary.isEmpty, isTrue);
      expect(summary.available, 0);
    });
  });

  group('limpieza de textos', () {
    test('quita caracteres de control y espacios', () {
      expect(sanitizeMovementText('  Éxito\u0000\n '), 'Éxito');
    });

    test('el texto del OCR se recorta y vacío es null', () {
      expect(sanitizeDetectedText('a' * 300), hasLength(movementTextMaxLength));
      expect(sanitizeDetectedText(' \t '), isNull);
      expect(sanitizeDetectedText(null), isNull);
    });
  });
}
