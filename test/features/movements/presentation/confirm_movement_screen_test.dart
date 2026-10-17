import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  group('Fecha del gasto (RF-19)', () {
    const manual = CreateMovementMode(MovementEntryMethod.manual);

    ProviderContainer containerOf(WidgetTester tester) =>
        ProviderScope.containerOf(
          tester.element(find.byType(ConfirmMovementScreen)),
        );

    Future<void> showDate(WidgetTester tester, String label) async {
      await tester.scrollUntilVisible(
        find.text(label),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    Future<void> pickDay(
      WidgetTester tester,
      String current,
      String day,
    ) async {
      await showDate(tester, current);
      await tester.tap(find.text(current));
      await tester.pumpAndSettle();
      await tester.tap(find.text(day));
      await tester.tap(find.text('ACEPTAR'));
      await tester.pumpAndSettle();
    }

    /// Guarda con el ViewModel: el botón navega a Inicio, que no existe sin
    /// el router.
    Future<void> save(WidgetTester tester, ConfirmMovementMode mode) async {
      final error = await pumpUntilDone(
        tester,
        containerOf(tester)
            .read(confirmMovementViewModelProvider(mode).notifier)
            .save(),
      );
      expect(error, isNull);
    }

    Future<MovementRow> latest(WidgetTester tester, AppDatabase db) =>
        pumpUntilDone(
          tester,
          (db.select(db.movements)
                ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
                ..limit(1))
              .getSingle(),
        );

    testWidgetsWithDatabase('registrar con la fecha de ayer', (
      tester,
      db,
    ) async {
      await pumpScreen(
        tester,
        const ConfirmMovementScreen(mode: manual),
        database: db,
      );
      await tester.enterText(amountInput(), '25000');
      await tester.pump();
      await tester.tap(find.text('Transporte'));
      await tester.pumpAndSettle();

      await showDate(tester, 'Hoy, 22 de septiembre');
      expect(find.text('FECHA'), findsOneWidget);
      await pickDay(tester, 'Hoy, 22 de septiembre', '21');
      expect(find.text('Ayer, 21 de septiembre'), findsOneWidget);
      await save(tester, manual);

      final row = await latest(tester, db);
      expect(row.amount, 25000);
      expect(row.date, DateTime(2026, 9, 21));
    });

    testWidgetsWithDatabase('registrar por foto con un día del mes anterior', (
      tester,
      db,
    ) async {
      const photo = CreateMovementMode(MovementEntryMethod.photo);
      await pumpScreen(
        tester,
        const ConfirmMovementScreen(mode: photo),
        database: db,
      );
      await showDate(tester, 'Hoy, 22 de septiembre');
      await tester.tap(find.text('Hoy, 22 de septiembre'));
      await tester.pumpAndSettle();
      expect(find.text('Fecha del gasto'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      await tester.tap(find.text('31'));
      await tester.tap(find.text('ACEPTAR'));
      await tester.pumpAndSettle();
      expect(find.text('31 de agosto'), findsOneWidget);

      await save(tester, photo);
      final row = await latest(tester, db);
      expect(row.origin, 'foto');
      expect(row.date, DateTime(2026, 8, 31));
    });

    testWidgetsWithDatabase('el calendario va hasta hoy y no acepta mañana', (
      tester,
      db,
    ) async {
      await pumpScreen(
        tester,
        const ConfirmMovementScreen(mode: manual),
        database: db,
      );
      await showDate(tester, 'Hoy, 22 de septiembre');
      await tester.tap(find.text('Hoy, 22 de septiembre'));
      await tester.pumpAndSettle();
      final picker = tester.widget<CalendarDatePicker>(
        find.byType(CalendarDatePicker),
      );
      expect(picker.lastDate, DateTime(2026, 9, 22));
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      // El ViewModel tampoco acepta una fecha futura.
      containerOf(tester)
          .read(confirmMovementViewModelProvider(manual).notifier)
          .setDate(DateTime(2026, 9, 23));
      await tester.pump();
      expect(find.text('Hoy, 22 de septiembre'), findsOneWidget);
    });

    testWidgetsWithDatabase('editar la fecha de un gasto', (tester, db) async {
      final id = await movementIdOf(tester, db, 'Éxito');
      final mode = EditMovementMode(id);
      await pumpScreen(tester, ConfirmMovementScreen(mode: mode), database: db);

      await pickDay(tester, 'Hoy, 22 de septiembre', '20');
      expect(find.text('20 de septiembre'), findsOneWidget);
      await save(tester, mode);

      final row = await pumpUntilDone(
        tester,
        (db.select(db.movements)..where((t) => t.id.equals(id))).getSingle(),
      );
      expect(row.date, DateTime(2026, 9, 20));
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

    testWidgetsWithDatabase(
      'ingreso: formulario de ingreso con valor, descripción y fecha',
      (tester, db) async {
        final id = await movementIdOf(tester, db, 'Salario');
        await pumpScreen(
          tester,
          ConfirmMovementScreen(mode: EditMovementMode(id)),
          database: db,
        );

        expect(find.text('VALOR DEL INGRESO'), findsOneWidget);
        expect(find.text('3.800.000'), findsOneWidget);
        expect(find.text('DESCRIPCIÓN'), findsOneWidget);
        expect(find.widgetWithText(TextField, 'Salario'), findsOneWidget);
        expect(find.text('FECHA'), findsOneWidget);
        expect(find.text('1 de septiembre'), findsOneWidget);
        // Sin categorías ni nota: el tipo no cambia al editar.
        expect(find.byType(AppChip), findsNothing);
        expect(find.text('NOTA (OPCIONAL)'), findsNothing);
      },
    );

    testWidgetsWithDatabase('ingreso: el calendario no ofrece días futuros', (
      tester,
      db,
    ) async {
      final id = await movementIdOf(tester, db, 'Salario');
      await pumpScreen(
        tester,
        ConfirmMovementScreen(mode: EditMovementMode(id)),
        database: db,
      );

      await tester.tap(find.text('1 de septiembre'));
      await tester.pumpAndSettle();
      final picker = tester.widget<CalendarDatePicker>(
        find.byType(CalendarDatePicker),
      );
      expect(picker.lastDate, DateTime(2026, 9, 22));
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

      await tester.scrollUntilVisible(
        find.text('Mercado de la semana'),
        200,
        scrollable: find.byType(Scrollable).first,
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
