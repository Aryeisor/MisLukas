import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/theme/app_spacing.dart';
import 'package:mislukas/core/utils/utils_providers.dart';
import 'package:mislukas/core/widgets/widgets.dart';
import 'package:mislukas/features/movements/domain/entities/movement.dart';
import 'package:mislukas/features/movements/presentation/new_movement_screen.dart';

import '../../../helpers/domain_fixtures.dart';
import '../../../helpers/pump_screen.dart';
import '../../../helpers/test_database.dart';

void main() {
  bool selected(WidgetTester tester, String title) => tester
      .widget<SelectableOptionCard>(
        find.widgetWithText(SelectableOptionCard, title),
      )
      .selected;

  Finder saveIncome() =>
      find.widgetWithText(AppPrimaryButton, 'Guardar ingreso');

  bool canSaveIncome(WidgetTester tester) =>
      tester.widget<AppPrimaryButton>(saveIncome()).onPressed != null;

  Finder amountInput() => find.descendant(
    of: find.byType(AppAmountField),
    matching: find.byType(TextField),
  );

  testWidgets('Foto del recibo viene seleccionada y se puede cambiar', (
    tester,
  ) async {
    await pumpScreen(tester, const NewMovementScreen());

    expect(find.text('Nuevo gasto'), findsOneWidget);
    expect(find.text('Recomendado'), findsOneWidget);
    expect(selected(tester, 'Foto del recibo'), isTrue);
    expect(selected(tester, 'Registro manual'), isFalse);

    await tester.tap(find.text('Registro manual'));
    await tester.pumpAndSettle();
    expect(selected(tester, 'Foto del recibo'), isFalse);
    expect(selected(tester, 'Registro manual'), isTrue);
  });

  group('Selector Gasto | Ingreso', () {
    testWidgets('Gasto viene seleccionado, con etiqueta y 48 dp', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpScreen(tester, const NewMovementScreen());

      expect(find.bySemanticsLabel('Tipo de movimiento'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Gasto')),
        matchesSemantics(
          label: 'Gasto',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
          isFocusable: true,
          hasFocusAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.text('Ingreso')),
        matchesSemantics(
          label: 'Ingreso',
          isButton: true,
          isSelected: false,
          hasSelectedState: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
          isFocusable: true,
          hasFocusAction: true,
        ),
      );
      for (final label in NewMovementScreen.typeLabels) {
        final size = tester.getSize(
          find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
        );
        expect(size.height, greaterThanOrEqualTo(AppSpacing.minTouchTarget));
      }
      semantics.dispose();
    });

    testWidgets('Ingreso cambia a su formulario, sin métodos ni categorías', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const NewMovementScreen(),
        overrides: [clockProvider.overrideWithValue(testClock)],
      );
      await tester.tap(find.text('Ingreso'));
      await tester.pumpAndSettle();

      expect(find.text('Nuevo ingreso'), findsOneWidget);
      expect(find.text('¿Cuánto dinero recibiste?'), findsOneWidget);
      expect(find.byType(SelectableOptionCard), findsNothing);
      expect(find.byType(AppChip), findsNothing);
      expect(find.text('VALOR DEL INGRESO'), findsOneWidget);
      expect(find.text('DESCRIPCIÓN'), findsOneWidget);
      expect(find.text('FECHA'), findsOneWidget);
      expect(find.text('Hoy, 22 de septiembre'), findsOneWidget);
      expect(saveIncome(), findsOneWidget);
      expect(find.text('Continuar'), findsNothing);

      // Volver a Gasto deja todo como antes.
      await tester.tap(find.text('Gasto'));
      await tester.pumpAndSettle();
      expect(find.text('Nuevo gasto'), findsOneWidget);
      expect(find.byType(SelectableOptionCard), findsNWidgets(2));
      expect(find.text('Continuar'), findsOneWidget);
    });

    testWidgets('la ruta puede abrirla con Ingreso seleccionado', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const NewMovementScreen(initialType: MovementType.income),
      );
      expect(find.text('Nuevo ingreso'), findsOneWidget);
    });
  });

  group('Formulario de ingreso', () {
    testWidgetsWithDatabase('Guardar requiere un valor mayor que cero', (
      tester,
      db,
    ) async {
      await pumpScreen(
        tester,
        const NewMovementScreen(initialType: MovementType.income),
        database: db,
      );
      expect(canSaveIncome(tester), isFalse, reason: 'vacío');

      await tester.enterText(amountInput(), '0');
      await tester.pump();
      expect(canSaveIncome(tester), isFalse, reason: 'cero');

      await tester.enterText(amountInput(), '3800000');
      await tester.pump();
      expect(canSaveIncome(tester), isTrue);
    });

    testWidgetsWithDatabase('el calendario va hasta hoy, sin días futuros', (
      tester,
      db,
    ) async {
      await pumpScreen(
        tester,
        const NewMovementScreen(initialType: MovementType.income),
        database: db,
      );
      await tester.tap(find.text('Hoy, 22 de septiembre'));
      await tester.pumpAndSettle();

      final picker = tester.widget<CalendarDatePicker>(
        find.byType(CalendarDatePicker),
      );
      expect(picker.lastDate, DateTime(2026, 9, 22));
      expect(picker.initialDate, DateTime(2026, 9, 22));
      // En español.
      expect(find.text('Fecha del ingreso'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);

      await tester.tap(find.text('21'));
      await tester.tap(find.text('ACEPTAR'));
      await tester.pumpAndSettle();
      expect(find.text('Ayer, 21 de septiembre'), findsOneWidget);
    });

    testWidgets('la fecha tiene etiqueta para lectores de pantalla', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpScreen(
        tester,
        const NewMovementScreen(initialType: MovementType.income),
        overrides: [clockProvider.overrideWithValue(testClock)],
      );
      final date = tester.getSemantics(find.text('FECHA'));
      expect(date.label, 'FECHA\nHoy, 22 de septiembre');
      expect(date.hint, 'Toca para cambiarla');
      expect(date.flagsCollection.isButton, isTrue);
      semantics.dispose();
    });
  });

  for (final type in MovementType.values) {
    testWidgets('sin overflow en 320 x 640 con texto al 130% (${type.name})', (
      tester,
    ) async {
      useSmallScreen(tester);
      await pumpScreen(tester, NewMovementScreen(initialType: type));
      await expectNoOverflowWhileScrolling(tester);
    });
  }
}
