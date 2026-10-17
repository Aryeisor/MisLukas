import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/database/app_database.dart';
import 'package:mislukas/core/widgets/widgets.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';
import 'package:mislukas/features/budgets/presentation/budgets_screen.dart';
import 'package:mislukas/features/profile/presentation/profile_screen.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/pump_screen.dart';
import '../../../helpers/test_database.dart';

/// Presupuestos (RF-52). La demo tiene Mercado con $1.150.000 en septiembre
/// y $897.000 gastados.
void main() {
  Finder limitInput() => find.descendant(
    of: find.byType(AppAmountField),
    matching: find.byType(TextField),
  );

  Finder saveButton() => find.widgetWithText(AppPrimaryButton, 'Guardar');

  bool canSave(WidgetTester tester) =>
      tester.widget<AppPrimaryButton>(saveButton()).onPressed != null;

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<List<BudgetRow>> activeBudgets(WidgetTester tester, AppDatabase db) =>
      pumpUntilDone(
        tester,
        (db.select(db.budgets)..where((t) => t.deletedAt.isNull())).get(),
      );

  testWidgetsWithDatabase('lista las categorías con gastado, límite y %', (
    tester,
    db,
  ) async {
    await pumpScreen(tester, const BudgetsScreen(), database: db);

    expect(find.text('Presupuestos'), findsOneWidget);
    expect(find.text('Septiembre 2026'), findsOneWidget);
    expect(find.text('Gastado \$897.000 de \$1.150.000'), findsOneWidget);
    expect(find.text('78% · Te quedan \$253.000'), findsOneWidget);
    expect(find.byType(AppVariationBar), findsOneWidget);
    // Las demás categorías no tienen presupuesto.
    expect(find.text('Transporte'), findsOneWidget);
    expect(find.text('Sin presupuesto. Toca para definirlo.'), findsWidgets);
  });

  testWidgetsWithDatabase('crear un presupuesto; cero o vacío no se acepta', (
    tester,
    db,
  ) async {
    await pumpScreen(tester, const BudgetsScreen(), database: db);

    await tapVisible(tester, find.text('Transporte'));
    expect(find.text('LÍMITE MENSUAL DE TRANSPORTE'), findsOneWidget);
    expect(canSave(tester), isFalse, reason: 'vacío');
    // Sin presupuesto no hay nada que quitar.
    expect(find.text('Quitar presupuesto'), findsNothing);

    await tester.enterText(limitInput(), '0');
    await tester.pump();
    expect(canSave(tester), isFalse, reason: 'cero');

    await tester.enterText(limitInput(), '300000');
    await tester.pump();
    expect(canSave(tester), isTrue);
    await tester.tap(saveButton());
    await tester.pumpAndSettle();

    expect(find.text('Presupuesto guardado'), findsOneWidget);
    expect(find.byType(AppAmountField), findsNothing);
    // La demo tiene $427.600 de transporte: 142%.
    await tester.scrollUntilVisible(
      find.text('Gastado \$427.600 de \$300.000'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('142% · Superaste el límite por \$127.600'),
      findsOneWidget,
    );
    final transport = (await activeBudgets(
      tester,
      db,
    )).where((b) => b.categoryId == DefaultCategory.transporte.id).single;
    expect(transport.limitAmount, 300000);
    expect(transport.month, DateTime(2026, 9));
  });

  testWidgetsWithDatabase('editar el límite conserva el presupuesto', (
    tester,
    db,
  ) async {
    final before = (await activeBudgets(tester, db)).single;
    await pumpScreen(tester, const BudgetsScreen(), database: db);

    await tapVisible(tester, find.text('Mercado'));
    expect(find.text('1.150.000'), findsOneWidget);
    await tester.enterText(limitInput(), '2000000');
    await tester.pump();
    await tester.tap(saveButton());
    await tester.pumpAndSettle();

    expect(find.text('Gastado \$897.000 de \$2.000.000'), findsOneWidget);
    final after = (await activeBudgets(tester, db)).single;
    expect(after.id, before.id);
    expect(after.limitAmount, 2000000);
  });

  testWidgetsWithDatabase('Cancelar cierra la edición sin guardar', (
    tester,
    db,
  ) async {
    await pumpScreen(tester, const BudgetsScreen(), database: db);

    await tapVisible(tester, find.text('Mercado'));
    await tester.enterText(limitInput(), '5');
    await tester.pump();
    await tester.tap(find.widgetWithText(AppSecondaryButton, 'Cancelar'));
    await tester.pumpAndSettle();

    expect(find.byType(AppAmountField), findsNothing);
    expect(find.text('Gastado \$897.000 de \$1.150.000'), findsOneWidget);
  });

  testWidgetsWithDatabase('quitar pide confirmar y deja la categoría sin '
      'presupuesto', (tester, db) async {
    await pumpScreen(tester, const BudgetsScreen(), database: db);

    await tapVisible(tester, find.text('Mercado'));
    await tapVisible(
      tester,
      find.widgetWithText(AppSecondaryButton, 'Quitar presupuesto'),
    );
    expect(find.text('¿Quitar el presupuesto de mercado?'), findsOneWidget);

    // Cancelar en el diálogo no quita nada.
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();
    expect(await activeBudgets(tester, db), hasLength(1));

    await tapVisible(
      tester,
      find.widgetWithText(AppSecondaryButton, 'Quitar presupuesto'),
    );
    await tester.tap(find.widgetWithText(TextButton, 'Quitar'));
    await tester.pumpAndSettle();

    expect(find.text('Presupuesto quitado'), findsOneWidget);
    expect(find.text('Gastado \$897.000 de \$1.150.000'), findsNothing);
    expect(await activeBudgets(tester, db), isEmpty);
  });

  testWidgetsWithDatabase('Perfil › Presupuestos abre la pantalla', (
    tester,
    db,
  ) async {
    await pumpApp(
      tester,
      database: db,
      auth: FakeAuthRepository(signedInAs: testUser),
    );
    await openTab(tester, 'Perfil');
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Preferencias'), findsOneWidget);

    final button = find.widgetWithText(AppSecondaryButton, 'Presupuestos');
    await tester.scrollUntilVisible(
      button,
      200,
      scrollable: find
          .descendant(
            of: find.byType(ProfileScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.byType(BudgetsScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
  });

  testWidgetsWithDatabase('sin overflow en 320 x 640 con texto al 130%', (
    tester,
    db,
  ) async {
    useSmallScreen(tester);
    await pumpScreen(tester, const BudgetsScreen(), database: db);
    await tapVisible(tester, find.text('Mercado'));
    await expectNoOverflowWhileScrolling(tester);
  });
}
