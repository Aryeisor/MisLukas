import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/widgets/widgets.dart';
import 'package:mislukas/features/movements/presentation/confirm_movement_screen.dart';
import 'package:mislukas/features/movements/presentation/movement_entry_method.dart';

import '../../../helpers/pump_screen.dart';

void main() {
  Finder saveButton() => find.widgetWithText(AppPrimaryButton, 'Guardar gasto');

  bool canSave(WidgetTester tester) =>
      tester.widget<AppPrimaryButton>(saveButton()).onPressed != null;

  Finder amountInput() => find.descendant(
    of: find.byType(AppAmountField),
    matching: find.byType(TextField),
  );

  bool chipSelected(WidgetTester tester, String label) =>
      tester.widget<AppChip>(find.widgetWithText(AppChip, label)).selected;

  group('Variante foto', () {
    testWidgets('precarga el valor y Mercado, y permite guardar', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const ConfirmMovementScreen(method: MovementEntryMethod.photo),
      );

      expect(find.text('Confirma los datos'), findsOneWidget);
      expect(find.text('Recibo leído correctamente'), findsOneWidget);
      expect(find.text('ÉXITO AV. EL DORADO'), findsOneWidget);
      expect(find.text('Área detectada'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('CATEGORÍA SUGERIDA'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('VALOR DETECTADO'), findsOneWidget);
      expect(find.text('CATEGORÍA SUGERIDA'), findsOneWidget);
      expect(chipSelected(tester, 'Mercado'), isTrue);
      expect(canSave(tester), isTrue);
    });

    testWidgets('sin valor el botón se deshabilita', (tester) async {
      await pumpScreen(
        tester,
        const ConfirmMovementScreen(method: MovementEntryMethod.photo),
      );

      await tester.enterText(amountInput(), '');
      await tester.pump();
      expect(canSave(tester), isFalse);

      await tester.enterText(amountInput(), '0');
      await tester.pump();
      expect(canSave(tester), isFalse);
    });
  });

  group('Variante manual', () {
    testWidgets('sin banner, sin recibo y sin categoría preseleccionada', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const ConfirmMovementScreen(method: MovementEntryMethod.manual),
      );

      expect(find.text('Registra tu gasto'), findsOneWidget);
      expect(find.byType(AppBanner), findsNothing);
      expect(find.byType(ReceiptPreview), findsNothing);
      expect(find.text('VALOR DEL GASTO'), findsOneWidget);
      expect(find.text('CATEGORÍA'), findsOneWidget);
      for (final label in [
        'Mercado',
        'Transporte',
        'Ocio',
        'Servicios',
        'Restaurantes',
      ]) {
        expect(chipSelected(tester, label), isFalse, reason: label);
      }
      expect(canSave(tester), isFalse);
    });

    testWidgets('requiere valor y categoría para guardar', (tester) async {
      await pumpScreen(
        tester,
        const ConfirmMovementScreen(method: MovementEntryMethod.manual),
      );

      await tester.enterText(amountInput(), '25000');
      await tester.pump();
      expect(canSave(tester), isFalse, reason: 'falta la categoría');

      await tester.tap(find.text('Transporte'));
      await tester.pumpAndSettle();
      expect(canSave(tester), isTrue);

      await tester.enterText(amountInput(), '');
      await tester.pump();
      expect(canSave(tester), isFalse, reason: 'falta el valor');
    });
  });

  group('Pantalla pequeña (320 x 640, texto al 130%)', () {
    for (final method in MovementEntryMethod.values) {
      testWidgets('variante ${method.name} sin overflow', (tester) async {
        useSmallScreen(tester);
        await pumpScreen(tester, ConfirmMovementScreen(method: method));
        await expectNoOverflowWhileScrolling(tester);
      });
    }
  });
}
