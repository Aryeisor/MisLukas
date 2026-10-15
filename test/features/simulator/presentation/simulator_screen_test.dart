import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mislukas/core/utils/currency_formatter.dart';
import 'package:mislukas/core/widgets/widgets.dart';
import 'package:mislukas/features/simulator/domain/savings_calculator.dart';
import 'package:mislukas/features/simulator/presentation/simulator_providers.dart';
import 'package:mislukas/features/simulator/presentation/simulator_screen.dart';

import '../../../helpers/domain_fixtures.dart';
import '../../../helpers/pump_screen.dart';
import '../../../helpers/test_database.dart';

void main() {
  Future<void> showText(WidgetTester tester, Finder finder) {
    return tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }

  testWidgetsWithDatabase(
    'muestra el promedio, los controles y los resultados a 3 años',
    (tester, db) async {
      await pumpScreen(tester, const SimulatorScreen(), database: db);

      expect(find.text('Simulador de ahorro'), findsOneWidget);
      expect(
        find.text('Basado en tu ritmo real de los últimos 3 meses'),
        findsOneWidget,
      );
      expect(find.text('Ahorras en promedio'), findsOneWidget);
      expect(find.text('\$420.000 / mes'), findsOneWidget);
      expect(find.text('Junio – Agosto 2026'), findsOneWidget);
      expect(find.text('3 años'), findsOneWidget);
      expect(find.text('\$420.000'), findsOneWidget);

      await showText(tester, find.text('\$16.716.595'));
      expect(find.text('\$15.120.000'), findsOneWidget);
      expect(find.text('+\$1.596.595 en intereses'), findsOneWidget);

      await showText(tester, find.text(simulatorDisclaimer));
      expect(find.text('¿Y si ahorras \$50.000 más al mes?'), findsOneWidget);
      expect(
        find.text(
          'Llegarías a \$18.706.666 en 3 años con interés — \$1.990.071 más.',
        ),
        findsOneWidget,
      );
      expect(find.byType(AppBarComparisonChart), findsOneWidget);
    },
  );

  testWidgetsWithDatabase('recalcula al mover el slider', (tester, db) async {
    await pumpScreen(tester, const SimulatorScreen(), database: db);

    await tester.drag(find.byType(Slider), const Offset(1000, 0));
    await tester.pumpAndSettle();

    expect(find.text('10 años'), findsNWidgets(2));
    final tenYears = projectSavings(monthlyContribution: 420000, years: 10);
    await showText(
      tester,
      find.text(CurrencyFormatter.format(tenYears.withInterest)),
    );
    expect(
      find.text(CurrencyFormatter.format(tenYears.withoutInterest)),
      findsOneWidget,
    );
    expect(find.text('\$16.716.595'), findsNothing);
  });

  testWidgetsWithDatabase('recalcula al tocar + y −', (tester, db) async {
    await pumpScreen(tester, const SimulatorScreen(), database: db);

    await tester.tap(find.byTooltip('Aumentar aporte'));
    await tester.pump();
    expect(find.text('\$470.000'), findsOneWidget);
    await showText(tester, find.text('\$16.920.000'));
    expect(find.text('\$18.706.666'), findsOneWidget);

    await tester.tap(find.byTooltip('Disminuir aporte'));
    await tester.pump();
    expect(find.text('\$15.120.000'), findsOneWidget);
    expect(find.text('\$16.716.595'), findsOneWidget);
  });

  testWidgets('− se deshabilita en el aporte mínimo', (tester) async {
    await pumpScreen(
      tester,
      const SimulatorScreen(),
      overrides: [
        savingsAverageProvider.overrideWithValue(
          AsyncData(savingsAverageOf(50000)),
        ),
      ],
    );

    final minus = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.remove),
    );
    expect(minus.onPressed, isNull);
  });

  testWidgets('ahorro negativo: mensaje en lugar de la proyección', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const SimulatorScreen(),
      overrides: [
        savingsAverageProvider.overrideWithValue(
          AsyncData(savingsAverageOf(-80000)),
        ),
      ],
    );

    expect(find.text('Aún no podemos proyectar tu ahorro'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    expect(find.byType(AppBarComparisonChart), findsNothing);
    expect(find.text(simulatorDisclaimer), findsOneWidget);
  });

  testWidgets('sin datos suficientes', (tester) async {
    await pumpScreen(
      tester,
      const SimulatorScreen(),
      overrides: [
        savingsAverageProvider.overrideWithValue(
          AsyncData(savingsAverageOf(null)),
        ),
      ],
    );

    expect(
      find.text('Necesitamos al menos un mes de datos para calcular tu ahorro'),
      findsOneWidget,
    );
    expect(find.byType(Slider), findsNothing);
  });

  testWidgetsWithDatabase(
    'sin overflow en 320 x 640 con texto al 130%, con la barra',
    (tester, db) async {
      useSmallScreen(tester);
      await pumpApp(tester, database: db);
      await loginAsDemoUser(tester);
      await openTab(tester, 'Simular');

      expect(find.byType(SimulatorScreen), findsOneWidget);
      // Con 10 años las etiquetas del gráfico no deben encimarse ni desbordar.
      await tester.ensureVisible(find.byType(Slider));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Slider), const Offset(1000, 0));
      await tester.pumpAndSettle();
      expect(find.text('10 años'), findsNWidgets(2));
      await expectNoOverflowWhileScrolling(tester);
      expect(find.text(simulatorDisclaimer).hitTestable(), findsOneWidget);
    },
  );
}
