import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/theme/app_colors.dart';
import 'package:mislukas/core/widgets/widgets.dart';

import '../../helpers/pump_themed.dart';

void main() {
  testWidgets('AppDonutChart describe sus porciones', (tester) async {
    await pumpThemed(
      tester,
      const Center(
        child: AppDonutChart(
          semanticsPrefix: 'Gastos por categoría',
          segments: [
            AppChartSegment(
              value: 38,
              color: AppColors.categoryMercado,
              label: 'Mercado 38%',
            ),
            AppChartSegment(
              value: 62,
              color: AppColors.categoryOcio,
              label: 'Ocio 62%',
            ),
          ],
          center: Text('Total'),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('Gastos por categoría. Mercado 38%, Ocio 62%'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppDonutChart sin valores no falla', (tester) async {
    await pumpThemed(
      tester,
      const Center(child: AppDonutChart(segments: [])),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppBarComparisonChart con 10 grupos en 248 px y texto al 130%', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpThemed(
      tester,
      Center(
        child: SizedBox(
          width: 248,
          child: AppBarComparisonChart(
            secondaryLabel: 'Sin interés',
            primaryLabel: 'Con interés (7% EA)',
            groups: [
              for (var year = 1; year <= 10; year++)
                AppBarGroup(
                  label: 'A$year',
                  secondary: year * 100,
                  primary: year * 110,
                  semanticLabel: 'Año $year',
                ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel(RegExp(r'^Año 1; .*Año 10$')), findsOneWidget);
    expect(find.text('Sin interés'), findsOneWidget);
    expect(find.text('Con interés (7% EA)'), findsOneWidget);
  });

  testWidgets('AppStatCard muestra etiqueta, valor y destacado', (tester) async {
    await pumpThemed(
      tester,
      const AppStatCard(
        label: 'Con interés',
        value: r'$16.716.595',
        description: '7% EA estimado',
        highlight: r'+$1.596.595 en intereses',
        highlighted: true,
      ),
    );

    expect(find.text('CON INTERÉS'), findsOneWidget);
    expect(find.text(r'$16.716.595'), findsOneWidget);
    expect(find.text('7% EA estimado'), findsOneWidget);
    expect(find.text(r'+$1.596.595 en intereses'), findsOneWidget);
  });

  testWidgets('AppVariationBar es decorativa', (tester) async {
    await pumpThemed(
      tester,
      const AppVariationBar(fraction: 1.5, color: AppColors.error),
    );
    expect(tester.takeException(), isNull);
  });
}
