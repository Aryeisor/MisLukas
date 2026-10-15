import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/widgets/widgets.dart';
import 'package:mislukas/features/reports/presentation/reports_screen.dart';

import '../../../helpers/pump_screen.dart';
import '../../../helpers/test_database.dart';

void main() {
  testWidgetsWithDatabase(
    'muestra el total y las 5 categorías con sus porcentajes',
    (tester, db) async {
      await pumpScreen(tester, const ReportsScreen(), database: db);

      expect(find.text('Septiembre 2026'), findsOneWidget);
      expect(find.text('Tus gastos de septiembre'), findsOneWidget);
      expect(find.text('\$2.375.680'), findsOneWidget);
      expect(find.text('Por categoría'), findsOneWidget);
      expect(find.byType(AppDonutChart), findsOneWidget);

      const expected = {
        'Mercado': '38%',
        'Ocio': '22%',
        'Transporte': '18%',
        'Servicios': '13%',
        'Otros': '9%',
      };
      for (final entry in expected.entries) {
        expect(
          find.widgetWithText(AppLegendItem, entry.value),
          findsOneWidget,
          reason: entry.key,
        );
        final item = tester.widget<AppLegendItem>(
          find.widgetWithText(AppLegendItem, entry.value),
        );
        expect(item.label, entry.key);
      }
    },
  );

  testWidgetsWithDatabase('compara con agosto con signo y porcentaje', (
    tester,
    db,
  ) async {
    await pumpScreen(tester, const ReportsScreen(), database: db);

    final title = find.text('Vs. agosto 2026');
    await tester.scrollUntilVisible(
      title,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(title, findsOneWidget);
    for (final text in ['+12%', '−8%', '+31%', '−4%', '+5%']) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(find.byType(AppVariationBar), findsNWidgets(5));
    expect(find.text('Aumento'), findsOneWidget);
    expect(find.text('Reducción'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Ocio, aumento del 31% frente a agosto 2026'),
      findsOneWidget,
    );
  });

  testWidgetsWithDatabase('estado vacío sin gastos en el mes', (
    tester,
    db,
  ) async {
    await pumpScreen(tester, const ReportsScreen(), database: db);

    expect(find.text('Aún no tienes gastos este mes'), findsOneWidget);
    expect(find.byType(AppDonutChart), findsNothing);
    expect(find.text('Registrar un gasto'), findsOneWidget);
  }, seed: false);

  testWidgetsWithDatabase('sin datos de agosto oculta la comparación', (
    tester,
    db,
  ) async {
    // Borra los movimientos del mes anterior.
    await pumpUntilDone(
      tester,
      (db.delete(
        db.movements,
      )..where((t) => t.date.isSmallerThanValue('2026-09-01'))).go(),
    );
    await pumpScreen(tester, const ReportsScreen(), database: db);

    expect(find.byType(AppDonutChart), findsOneWidget);
    expect(find.textContaining('Vs.'), findsNothing);
    expect(find.byType(AppVariationBar), findsNothing);
  });

  testWidgetsWithDatabase(
    'sin overflow en 320 x 640 con texto al 130%, con la barra',
    (tester, db) async {
      useSmallScreen(tester);
      await pumpApp(tester, database: db);
      await loginAsDemoUser(tester);
      await openTab(tester, 'Reportes');

      expect(find.byType(ReportsScreen), findsOneWidget);
      await expectNoOverflowWhileScrolling(tester);
      // Al final del desplazamiento la leyenda queda visible sobre la barra.
      expect(find.text('Reducción').hitTestable(), findsOneWidget);
    },
  );
}
