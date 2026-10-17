import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mislukas/core/router/app_routes.dart';
import 'package:mislukas/core/theme/category_style.dart';
import 'package:mislukas/core/widgets/widgets.dart';
import 'package:mislukas/features/home/presentation/home_screen.dart';
import 'package:mislukas/features/reports/presentation/reports_screen.dart';

import 'helpers/pump_screen.dart';
import 'helpers/test_database.dart';

void main() {
  Finder snackbarText(String text) =>
      find.descendant(of: find.byType(SnackBar), matching: find.text(text));

  Finder amountInput() => find.descendant(
    of: find.byType(AppAmountField),
    matching: find.byType(TextField),
  );

  /// Abre la edición del primer movimiento de Inicio (Éxito, hoy).
  Future<void> editFirstMovement(WidgetTester tester) async {
    final tile = find.byType(MovementTile).first;
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.text('Editar movimiento'), findsOneWidget);
  }

  Future<void> scrollReportsTo(WidgetTester tester, Finder finder) {
    return tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find
          .descendant(
            of: find.byType(ReportsScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }

  testWidgetsWithDatabase(
    'flujo completo: login → inicio → nuevo gasto → confirmar → inicio',
    (tester, db) async {
      await pumpApp(tester, database: db);
      await loginAsDemoUser(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('\$2.375.680'), findsOneWidget);

      // Nuevo gasto con registro manual.
      await tester.tap(find.text('Nuevo movimiento'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registro manual'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Registra tu gasto'), findsOneWidget);

      // Valor, categoría y nota.
      await tester.enterText(amountInput(), '25000');
      await tester.tap(find.text('Transporte'));
      await tester.pumpAndSettle();
      final noteField = find.descendant(
        of: find.ancestor(
          of: find.text('NOTA (OPCIONAL)'),
          matching: find.byType(AppTextField),
        ),
        matching: find.byType(TextField),
      );
      await tester.ensureVisible(noteField);
      await tester.enterText(noteField, 'Taxi');
      await tester.pump();

      await tester.tap(find.widgetWithText(AppPrimaryButton, 'Guardar gasto'));
      await tester.pumpAndSettle();

      // De vuelta en Inicio con el movimiento nuevo arriba.
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(AppBottomNav), findsOneWidget);
      expect(snackbarText('Gasto guardado'), findsOneWidget);

      final firstTile = tester.widget<MovementTile>(
        find.byType(MovementTile).first,
      );
      expect(firstTile.title, 'Taxi');
      expect(firstTile.amount, 25000);
      expect(firstTile.dateLabel, 'Hoy');

      // Los gastos suben y el disponible baja.
      expect(find.text('\$2.400.680'), findsOneWidget);
      expect(find.text('\$1.849.320'), findsOneWidget);
    },
  );

  testWidgetsWithDatabase(
    'registrar un ingreso: Nuevo movimiento → Ingreso → Inicio',
    (tester, db) async {
      await pumpApp(tester, database: db);
      await loginAsDemoUser(tester);
      expect(find.text('Aún no tienes movimientos este mes'), findsOneWidget);

      await tester.tap(find.text('Registrar un movimiento'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ingreso'));
      await tester.pumpAndSettle();
      await tester.enterText(amountInput(), '3800000');
      await tester.enterText(
        find.descendant(
          of: find.byType(AppTextField),
          matching: find.byType(TextField),
        ),
        'Salario',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(AppPrimaryButton, 'Guardar ingreso'));
      await tester.pumpAndSettle();

      // Inicio: el disponible es el ingreso y la fila va en verde con "+".
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(snackbarText('Ingreso guardado'), findsOneWidget);
      expect(find.text('\$3.800.000'), findsNWidgets(2));
      expect(find.text('\$0'), findsOneWidget);
      final tile = tester.widget<MovementTile>(find.byType(MovementTile));
      expect(tile.title, 'Salario');
      expect(tile.category, CategoryKind.ingreso);
      expect(tile.dateLabel, 'Hoy');
      expect(tile.isPendingSync, isTrue);
      expect(find.text('+\$3.800.000'), findsOneWidget);

      // Reportes es solo de gastos: sigue vacío.
      await openTab(tester, 'Reportes');
      expect(find.text('Aún no tienes gastos este mes'), findsOneWidget);
      expect(find.byType(AppDonutChart), findsNothing);

      // El simulador usa meses completos: este mes aún no cuenta.
      await openTab(tester, 'Simular');
      expect(
        find.text(
          'Necesitamos al menos un mes de datos para calcular tu ahorro',
        ),
        findsOneWidget,
      );
    },
    seed: false,
  );

  testWidgetsWithDatabase('editar un movimiento actualiza Inicio y Reportes', (
    tester,
    db,
  ) async {
    await pumpApp(tester, database: db);
    await loginAsDemoUser(tester);
    await editFirstMovement(tester);
    expect(find.text('87.400'), findsOneWidget);

    // Éxito pasa de 87.400 a 187.400.
    await tester.enterText(amountInput(), '187400');
    await tester.pump();
    await tester.tap(find.widgetWithText(AppPrimaryButton, 'Guardar cambios'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(snackbarText('Cambios guardados'), findsOneWidget);
    expect(
      tester.widget<MovementTile>(find.byType(MovementTile).first).amount,
      187400,
    );
    // La lista quedó desplazada hasta el movimiento.
    expect(find.text('\$2.475.680', skipOffstage: false), findsOneWidget);
    // 997.000 / 1.150.000 = 86%.
    expect(
      find.text('Presupuesto de mercado al 86%', skipOffstage: false),
      findsOneWidget,
    );

    await openTab(tester, 'Reportes');
    expect(find.text('\$2.475.680'), findsOneWidget);
    expect(
      tester
          .widget<AppLegendItem>(
            find.widgetWithText(AppLegendItem, 'Mercado').first,
          )
          .value,
      '40%',
    );
    // 997.000 frente a 801.000 en agosto: +24%.
    await scrollReportsTo(tester, find.text('+24%'));
    expect(find.text('+24%'), findsOneWidget);
  });

  testWidgetsWithDatabase(
    'eliminar un movimiento lo quita de Inicio y Reportes y lo deja en la cola',
    (tester, db) async {
      await pumpApp(tester, database: db);
      await loginAsDemoUser(tester);
      final id = await movementIdOf(tester, db, 'Éxito');
      await editFirstMovement(tester);

      // Cancelar no elimina.
      await tester.tap(find.text('Eliminar movimiento'));
      await tester.pumpAndSettle();
      expect(find.text('¿Eliminar este movimiento?'), findsOneWidget);
      expect(find.text('Esta acción no se puede deshacer.'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Editar movimiento'), findsOneWidget);

      await tester.tap(find.text('Eliminar movimiento'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(snackbarText('Movimiento eliminado'), findsOneWidget);
      final first = tester.widget<MovementTile>(
        find.byType(MovementTile).first,
      );
      expect(first.title, 'TransMilenio');
      // 2.375.680 − 87.400.
      expect(find.text('\$2.288.280', skipOffstage: false), findsOneWidget);

      await openTab(tester, 'Reportes');
      expect(find.text('\$2.288.280'), findsOneWidget);

      // Borrado lógico con su entrada en la cola de sincronización.
      final row = await pumpUntilDone(
        tester,
        (db.select(db.movements)..where((t) => t.id.equals(id))).getSingle(),
      );
      expect(row.deletedAt, isNotNull);
      final queue = await pumpUntilDone(
        tester,
        (db.select(db.syncQueue)..where(
              (t) => t.recordId.equals(id) & t.operation.equals('eliminar'),
            ))
            .get(),
      );
      expect(queue, hasLength(1));
      expect(queue.single.targetTable, 'movimientos');
    },
  );

  testWidgetsWithDatabase('también se edita un ingreso', (tester, db) async {
    await pumpApp(tester, database: db);
    await loginAsDemoUser(tester);

    // Salario no está entre los 5 últimos: se edita por su ruta.
    final id = await movementIdOf(tester, db, 'Salario');
    GoRouter.of(tester.element(find.byType(HomeScreen)))
        .push(AppRoutes.editMovementWith(id));
    await tester.pumpAndSettle();

    expect(find.text('VALOR DEL INGRESO'), findsOneWidget);
    await tester.enterText(amountInput(), '4000000');
    await tester.pump();
    await tester.tap(find.widgetWithText(AppPrimaryButton, 'Guardar cambios'));
    await tester.pumpAndSettle();

    // Ingresos 4.250.000 + 200.000.
    expect(find.text('\$4.450.000'), findsOneWidget);
  });

  testWidgetsWithDatabase(
    'editar un ingreso cambia valor, descripción y fecha',
    (tester, db) async {
      await pumpApp(tester, database: db);
      await loginAsDemoUser(tester);

      final id = await movementIdOf(tester, db, 'Salario');
      GoRouter.of(
        tester.element(find.byType(HomeScreen)),
      ).push(AppRoutes.editMovementWith(id));
      await tester.pumpAndSettle();

      await tester.enterText(amountInput(), '4000000');
      await tester.enterText(
        find.widgetWithText(TextField, 'Salario'),
        'Salario y prima',
      );
      await tester.pump();

      // Calendario del sistema en español, hasta hoy (22 de septiembre).
      await tester.tap(find.text('1 de septiembre'));
      await tester.pumpAndSettle();
      expect(find.text('Fecha del ingreso'), findsOneWidget);
      await tester.tap(find.text('15'));
      await tester.tap(find.text('ACEPTAR'));
      await tester.pumpAndSettle();
      expect(find.text('15 de septiembre'), findsOneWidget);

      await tester.tap(
        find.widgetWithText(AppPrimaryButton, 'Guardar cambios'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);

      final row = await pumpUntilDone(
        tester,
        (db.select(db.movements)..where((t) => t.id.equals(id))).getSingle(),
      );
      expect(row.amount, 4000000);
      expect(row.description, 'Salario y prima');
      expect(row.date, DateTime(2026, 9, 15));
      expect(row.type, 'ingreso');
      expect(row.syncStatus, 'pendiente');
    },
  );

  testWidgetsWithDatabase('eliminar un ingreso baja el disponible', (
    tester,
    db,
  ) async {
    await pumpApp(tester, database: db);
    await loginAsDemoUser(tester);

    final id = await movementIdOf(tester, db, 'Freelance');
    GoRouter.of(
      tester.element(find.byType(HomeScreen)),
    ).push(AppRoutes.editMovementWith(id));
    await tester.pumpAndSettle();

    final delete = find.text('Eliminar movimiento');
    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
    await tester.pumpAndSettle();

    // Ingresos 4.250.000 − 450.000; gastos 2.375.680.
    expect(find.text('\$3.800.000'), findsOneWidget);
    expect(find.text('\$1.424.320'), findsOneWidget);
  });

  testWidgetsWithDatabase('Borrar todos los datos deja la app vacía', (
    tester,
    db,
  ) async {
    await pumpApp(tester, database: db);
    await loginAsDemoUser(tester);
    await openTab(tester, 'Perfil');

    final clear = find.text('Borrar todos los datos');
    await tester.ensureVisible(clear);
    await tester.pumpAndSettle();
    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect(find.text('¿Borrar todos los datos?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Borrar'));
    await tester.pumpAndSettle();
    expect(snackbarText('Se borraron todos los datos'), findsOneWidget);

    await openTab(tester, 'Inicio');
    expect(find.text('Aún no tienes movimientos este mes'), findsOneWidget);
    await openTab(tester, 'Reportes');
    expect(find.text('Aún no tienes gastos este mes'), findsOneWidget);
    await openTab(tester, 'Simular');
    expect(
      find.text('Necesitamos al menos un mes de datos para calcular tu ahorro'),
      findsOneWidget,
    );

    final queue = await pumpUntilDone(tester, db.select(db.syncQueue).get());
    expect(queue, isEmpty);
    final categories = await pumpUntilDone(
      tester,
      db.select(db.categories).get(),
    );
    expect(categories, hasLength(7));

    // Y se pueden volver a cargar.
    await openTab(tester, 'Perfil');
    final load = find.text('Cargar datos de demostración');
    await tester.ensureVisible(load);
    await tester.pumpAndSettle();
    await tester.tap(load);
    await tester.pumpAndSettle();
    await openTab(tester, 'Inicio');
    expect(find.text('\$2.375.680'), findsOneWidget);
  });
}
