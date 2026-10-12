import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/demo/demo_data.dart';
import 'package:mislukas/core/widgets/widgets.dart';
import 'package:mislukas/features/reports/presentation/reports_screen.dart';

import '../../../helpers/pump_screen.dart';

void main() {
  testWidgets('muestra el total y las 5 categorías con sus porcentajes', (
    tester,
  ) async {
    await pumpScreen(tester, const ReportsScreen());

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
  });

  testWidgets('compara con agosto con signo y porcentaje', (tester) async {
    await pumpScreen(tester, const ReportsScreen());

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

  testWidgets('estado vacío sin gastos en el mes', (tester) async {
    await pumpScreen(
      tester,
      const ReportsScreen(),
      overrides: [
        demoSeedMovementsProvider.overrideWithValue(const []),
        demoUnlistedExpensesByMonthProvider.overrideWithValue(const {}),
      ],
    );

    expect(find.text('Aún no tienes gastos este mes'), findsOneWidget);
    expect(find.byType(AppDonutChart), findsNothing);
    expect(find.text('Registrar un gasto'), findsOneWidget);
  });

  testWidgets('sin datos de agosto oculta la comparación', (tester) async {
    await pumpScreen(
      tester,
      const ReportsScreen(),
      overrides: [
        demoUnlistedExpensesByMonthProvider.overrideWithValue({
          DateTime(2026, 9): demoUnlistedExpensesByMonth[DateTime(2026, 9)]!,
        }),
      ],
    );

    expect(find.byType(AppDonutChart), findsOneWidget);
    expect(find.textContaining('Vs.'), findsNothing);
    expect(find.byType(AppVariationBar), findsNothing);
  });

  testWidgets('sin overflow en 320 x 640 con texto al 130%, con la barra', (
    tester,
  ) async {
    useSmallScreen(tester);
    await pumpApp(tester);
    await loginAsDemoUser(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomNav),
        matching: find.text('Reportes'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ReportsScreen), findsOneWidget);
    await expectNoOverflowWhileScrolling(tester);
    // Al final del desplazamiento la leyenda queda visible sobre la barra.
    expect(find.text('Reducción').hitTestable(), findsOneWidget);
  });
}
