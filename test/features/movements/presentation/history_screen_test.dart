import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/theme/category_style.dart';
import 'package:mislukas/core/widgets/widgets.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';
import 'package:mislukas/features/home/presentation/home_screen.dart';
import 'package:mislukas/features/movements/data/drift_movement_repository.dart';
import 'package:mislukas/features/movements/presentation/confirm_movement_screen.dart';
import 'package:mislukas/features/movements/presentation/history/history_screen.dart';
import 'package:mislukas/features/movements/presentation/history/history_view_model.dart';

import '../../../helpers/domain_fixtures.dart';
import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/pump_screen.dart';
import '../../../helpers/test_database.dart';

void main() {
  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(HistoryScreen)));

  Finder historyList() => find
      .descendant(
        of: find.byType(HistoryScreen),
        matching: find.byType(Scrollable),
      )
      .last;

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 300, scrollable: historyList());
    await tester.pumpAndSettle();
  }

  Iterable<CategoryKind> visibleCategories(WidgetTester tester) => tester
      .widgetList<MovementTile>(find.byType(MovementTile))
      .map((tile) => tile.category);

  testWidgetsWithDatabase(
    'agrupa por mes con sus totales y carga los meses anteriores al bajar',
    (tester, db) async {
      await pumpScreen(tester, const HistoryScreen(), database: db);

      expect(find.text('Historial'), findsOneWidget);
      expect(find.text('Septiembre 2026'), findsOneWidget);
      expect(
        find.text('+\$4.250.000 ingresos · -\$2.375.680 gastos'),
        findsOneWidget,
      );
      // Primero el más reciente: hoy.
      expect(
        tester.widgetList<MovementTile>(find.byType(MovementTile)).first.title,
        'Éxito',
      );

      // Se cargan 3 meses de los 4 de la demo.
      final page = containerOf(tester).read(historyViewModelProvider).page;
      expect(page.value!.months, hasLength(3));
      expect(page.value!.hasMore, isTrue);

      await scrollTo(tester, find.text('Agosto 2026'));
      await scrollTo(tester, find.text('Junio 2026'));
      final all = containerOf(tester).read(historyViewModelProvider).page;
      expect(all.value!.months, hasLength(4));
      expect(all.value!.hasMore, isFalse);
    },
  );

  testWidgetsWithDatabase('filtro Ingresos: sin categorías y solo ingresos', (
    tester,
    db,
  ) async {
    await pumpScreen(tester, const HistoryScreen(), database: db);
    expect(find.text('Todas'), findsOneWidget);

    await tester.tap(find.text('Ingresos'));
    await tester.pumpAndSettle();

    expect(find.text('Todas'), findsNothing);
    // Los ingresos de la demo son iguales todos los meses.
    expect(find.text('+\$4.250.000 ingresos'), findsWidgets);
    expect(visibleCategories(tester), isNotEmpty);
    expect(visibleCategories(tester), everyElement(CategoryKind.ingreso));
  });

  testWidgetsWithDatabase('filtro Gastos y por categoría', (tester, db) async {
    await pumpScreen(tester, const HistoryScreen(), database: db);

    await tester.tap(find.text('Gastos'));
    await tester.pumpAndSettle();
    expect(visibleCategories(tester), isNot(contains(CategoryKind.ingreso)));

    await tester.tap(find.widgetWithText(AppChip, 'Transporte'));
    await tester.pumpAndSettle();
    expect(visibleCategories(tester), isNotEmpty);
    expect(visibleCategories(tester), everyElement(CategoryKind.transporte));
    expect(find.text('TransMilenio'), findsWidgets);
    expect(find.text('Éxito'), findsNothing);

    // Todas vuelve a mostrar todas las categorías de gasto.
    await tester.tap(find.widgetWithText(AppChip, 'Todas'));
    await tester.pumpAndSettle();
    expect(find.text('Éxito'), findsOneWidget);
  });

  testWidgetsWithDatabase(
    'no muestra eliminados y marca los pendientes de sincronizar',
    (tester, db) async {
      final repository = DriftMovementRepository(db);
      await pumpUntilDone(
        tester,
        repository.add(
          testMovement(
            id: 'borrado',
            description: 'Movimiento borrado',
            date: DateTime(2026, 9, 22),
          ),
        ),
      );
      await pumpUntilDone(
        tester,
        repository.softDelete('borrado', at: testToday),
      );

      await pumpScreen(tester, const HistoryScreen(), database: db);

      expect(find.text('Movimiento borrado'), findsNothing);
      // La demo aún no se sincroniza.
      expect(find.byTooltip('Pendiente de sincronizar'), findsWidgets);
    },
  );

  testWidgetsWithDatabase('sin movimientos: estado vacío con acción', (
    tester,
    db,
  ) async {
    await pumpScreen(tester, const HistoryScreen(), database: db);

    expect(find.text('Aún no tienes movimientos'), findsOneWidget);
    expect(find.text('Registrar un movimiento'), findsOneWidget);
  }, seed: false);

  testWidgetsWithDatabase('con un filtro sin resultados: otro mensaje', (
    tester,
    db,
  ) async {
    await pumpUntilDone(
      tester,
      DriftMovementRepository(db).add(testMovement(amount: 5000)),
    );
    await pumpScreen(tester, const HistoryScreen(), database: db);
    expect(find.byType(MovementTile), findsOneWidget);

    await tester.tap(find.text('Ingresos'));
    await tester.pumpAndSettle();

    expect(find.text('No hay movimientos con este filtro'), findsOneWidget);
    expect(find.text('Registrar un movimiento'), findsNothing);
  }, seed: false);

  testWidgetsWithDatabase(
    'Ver todos abre el historial; tocar un movimiento lo edita',
    (tester, db) async {
      await pumpApp(
        tester,
        database: db,
        auth: FakeAuthRepository(signedInAs: testUser),
      );
      expect(find.byType(HomeScreen), findsOneWidget);

      await tester.tap(find.text('Ver todos'));
      await tester.pumpAndSettle();
      expect(find.byType(HistoryScreen), findsOneWidget);

      // Un movimiento de agosto, que ya no está en Últimos movimientos.
      await tester.tap(find.text('Gastos'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppChip, 'Servicios'));
      await tester.pumpAndSettle();
      final august = await pumpUntilDone(
        tester,
        (db.select(db.movements)
              ..where(
                (t) =>
                    t.categoryId.equals(DefaultCategory.servicios.id) &
                    t.date.isBetweenValues('2026-08-01', '2026-08-31'),
              )
              ..limit(1))
            .getSingle(),
      );
      final augustTile = find.byKey(ValueKey(august.id));
      await scrollTo(tester, augustTile);
      await tester.tap(augustTile);
      await tester.pumpAndSettle();
      expect(find.byType(ConfirmMovementScreen), findsOneWidget);
      expect(find.text('Editar movimiento'), findsOneWidget);

      final amount = find.descendant(
        of: find.byType(AppAmountField),
        matching: find.byType(TextField),
      );
      await tester.enterText(amount, '123456');
      await tester.pump();
      await tester.tap(
        find.widgetWithText(AppPrimaryButton, 'Guardar cambios'),
      );
      await tester.pumpAndSettle();

      // Vuelve al historial con el valor nuevo.
      expect(find.byType(HistoryScreen), findsOneWidget);
      await scrollTo(tester, augustTile);
      expect(tester.widget<MovementTile>(augustTile).amount, 123456);
      final row = await pumpUntilDone(
        tester,
        (db.select(
          db.movements,
        )..where((t) => t.id.equals(august.id))).getSingle(),
      );
      expect(row.amount, 123456);
      expect(row.date.month, 8);
    },
  );

  testWidgetsWithDatabase('sin overflow en 320 x 640 con texto al 130%', (
    tester,
    db,
  ) async {
    useSmallScreen(tester);
    await pumpScreen(tester, const HistoryScreen(), database: db);
    await expectNoOverflowWhileScrolling(tester);
  });
}
