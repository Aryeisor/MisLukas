import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/demo/demo_data.dart';
import 'package:mislukas/core/widgets/widgets.dart';
import 'package:mislukas/features/home/presentation/home_screen.dart';

import '../../../helpers/pump_screen.dart';

void main() {
  testWidgets('muestra disponible, alerta y últimos movimientos', (
    tester,
  ) async {
    await pumpScreen(tester, const HomeScreen());

    expect(find.text('Septiembre 2026'), findsOneWidget);
    expect(find.text('Hola, Camila 👋'), findsOneWidget);
    expect(find.text('\$1.874.320'), findsOneWidget);
    expect(find.text('\$4.250.000'), findsOneWidget);
    expect(find.text('\$2.375.680'), findsOneWidget);
    expect(find.text('Presupuesto de mercado al 78%'), findsOneWidget);
    expect(
      find.text('Te quedan \$253.000 para fin de mes'),
      findsOneWidget,
    );
    expect(find.text('Últimos movimientos'), findsOneWidget);
    expect(find.byTooltip('Notificaciones'), findsOneWidget);
    expect(find.widgetWithText(AppPrimaryButton, 'Nuevo gasto'), findsOneWidget);
  });

  testWidgets('estado vacío sin movimientos', (tester) async {
    await pumpScreen(
      tester,
      const HomeScreen(),
      overrides: [demoSeedMovementsProvider.overrideWithValue(const [])],
    );

    expect(find.text('Aún no tienes movimientos este mes'), findsOneWidget);
    expect(find.byType(MovementTile), findsNothing);
  });

  testWidgets('sin overflow en 320 x 640 con texto al 130%, con la barra', (
    tester,
  ) async {
    useSmallScreen(tester);
    await pumpApp(tester);
    await loginAsDemoUser(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(AppBottomNav), findsOneWidget);
    await expectNoOverflowWhileScrolling(tester);
  });
}
