import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/theme/app_colors.dart';
import 'package:mislukas/core/theme/category_style.dart';
import 'package:mislukas/core/widgets/widgets.dart';

import '../../helpers/pump_themed.dart';

void main() {
  Color? colorOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style?.color;

  testWidgets('gasto: signo menos y texto principal', (tester) async {
    await pumpThemed(
      tester,
      const MovementTile(
        title: 'Éxito',
        category: CategoryKind.mercado,
        dateLabel: 'Hoy',
        amount: 87400,
      ),
    );

    expect(find.text('Éxito'), findsOneWidget);
    expect(find.text('Mercado · Hoy'), findsOneWidget);
    expect(colorOf(tester, '-\$87.400'), AppColors.textPrimary);
  });

  testWidgets('ingreso: signo más y color de éxito', (tester) async {
    await pumpThemed(
      tester,
      const MovementTile(
        title: 'Salario',
        category: CategoryKind.ingreso,
        dateLabel: 'Sep 1',
        amount: 3800000,
      ),
    );

    expect(colorOf(tester, '+\$3.800.000'), AppColors.success);
  });

  testWidgets('muestra el indicador de pendiente de sincronizar', (
    tester,
  ) async {
    await pumpThemed(
      tester,
      const MovementTile(
        title: 'Juan Valdez',
        category: CategoryKind.ocio,
        dateLabel: 'Sep 1',
        amount: 18500,
        isPendingSync: true,
      ),
    );

    expect(find.byTooltip('Pendiente de sincronizar'), findsOneWidget);
  });
}
