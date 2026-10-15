import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/database/app_database.dart';
import 'package:mislukas/core/widgets/widgets.dart';
import 'package:mislukas/features/movements/presentation/confirm_movement_screen.dart';
import 'package:mislukas/features/movements/presentation/confirm_movement_view_model.dart';
import 'package:mislukas/features/movements/presentation/movement_entry_method.dart';

import '../../../helpers/pump_screen.dart';
import '../../../helpers/test_database.dart';

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
        const ConfirmMovementScreen(
          mode: CreateMovementMode(MovementEntryMethod.photo),
        ),
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
        const ConfirmMovementScreen(
          mode: CreateMovementMode(MovementEntryMethod.photo),
        ),
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
        const ConfirmMovementScreen(
          mode: CreateMovementMode(MovementEntryMethod.manual),
        ),
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
        'Otros',
      ]) {
        expect(chipSelected(tester, label), isFalse, reason: label);
      }
      expect(canSave(tester), isFalse);
    });

    testWidgets('requiere valor y categoría para guardar', (tester) async {
      await pumpScreen(
        tester,
        const ConfirmMovementScreen(
          mode: CreateMovementMode(MovementEntryMethod.manual),
        ),
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

  group('Modo edición', () {
    testWidgetsWithDatabase('gasto: precarga valor, categoría y acciones', (
      tester,
      db,
    ) async {
      final id = await movementIdOf(tester, db, 'Éxito');
      await pumpScreen(
        tester,
        ConfirmMovementScreen(mode: EditMovementMode(id)),
        database: db,
      );

      expect(find.text('Editar movimiento'), findsOneWidget);
      expect(find.byType(AppBanner), findsNothing);
      expect(find.byType(ReceiptPreview), findsNothing);
      expect(find.text('VALOR DEL GASTO'), findsOneWidget);
      expect(find.text('87.400'), findsOneWidget);
      expect(chipSelected(tester, 'Mercado'), isTrue);
      expect(find.text('Ingreso'), findsNothing);
      expect(
        find.widgetWithText(AppPrimaryButton, 'Guardar cambios'),
        findsOneWidget,
      );
      final delete = tester.widget<AppSecondaryButton>(
        find.widgetWithText(AppSecondaryButton, 'Eliminar movimiento'),
      );
      expect(delete.destructive, isTrue);
    });

    testWidgetsWithDatabase('ingreso: solo la categoría Ingreso', (
      tester,
      db,
    ) async {
      final id = await movementIdOf(tester, db, 'Salario');
      await pumpScreen(
        tester,
        ConfirmMovementScreen(mode: EditMovementMode(id)),
        database: db,
      );

      expect(find.text('VALOR DEL INGRESO'), findsOneWidget);
      expect(find.text('3.800.000'), findsOneWidget);
      expect(find.byType(AppChip), findsOneWidget);
      expect(chipSelected(tester, 'Ingreso'), isTrue);
    });

    testWidgetsWithDatabase('la nota se precarga', (tester, db) async {
      final id = await movementIdOf(tester, db, 'Éxito');
      await pumpUntilDone(
        tester,
        (db.update(db.movements)..where((t) => t.id.equals(id))).write(
          const MovementsCompanion(note: Value('Mercado de la semana')),
        ),
      );
      await pumpScreen(
        tester,
        ConfirmMovementScreen(mode: EditMovementMode(id)),
        database: db,
      );

      expect(find.text('Mercado de la semana'), findsOneWidget);
    });

    testWidgetsWithDatabase('movimiento inexistente: mensaje de error', (
      tester,
      db,
    ) async {
      await pumpScreen(
        tester,
        const ConfirmMovementScreen(mode: EditMovementMode('no-existe')),
        database: db,
      );

      expect(find.text('No pudimos abrir este movimiento'), findsOneWidget);
      expect(find.text('Este movimiento ya no existe.'), findsOneWidget);
    });
  });

  group('Pantalla pequeña (320 x 640, texto al 130%)', () {
    for (final method in MovementEntryMethod.values) {
      testWidgets('variante ${method.name} sin overflow', (tester) async {
        useSmallScreen(tester);
        await pumpScreen(
          tester,
          ConfirmMovementScreen(mode: CreateMovementMode(method)),
        );
        await expectNoOverflowWhileScrolling(tester);
      });
    }

    for (final description in ['Éxito', 'Salario']) {
      testWidgetsWithDatabase('edición de $description sin overflow', (
        tester,
        db,
      ) async {
        useSmallScreen(tester);
        final id = await movementIdOf(tester, db, description);
        await pumpScreen(
          tester,
          ConfirmMovementScreen(mode: EditMovementMode(id)),
          database: db,
        );
        expect(find.text('Editar movimiento'), findsOneWidget);
        await expectNoOverflowWhileScrolling(tester);
        expect(find.text('Eliminar movimiento').hitTestable(), findsOneWidget);
      });
    }
  });
}
