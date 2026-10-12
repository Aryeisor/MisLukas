import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/app.dart';
import 'package:mislukas/core/widgets/widgets.dart';
import 'package:mislukas/features/auth/presentation/login_screen.dart';
import 'package:mislukas/features/home/presentation/home_screen.dart';
import 'package:mislukas/features/movements/presentation/confirm_movement_screen.dart';
import 'package:mislukas/features/movements/presentation/new_movement_screen.dart';
import 'package:mislukas/features/profile/presentation/profile_screen.dart';
import 'package:mislukas/features/reports/presentation/reports_screen.dart';
import 'package:mislukas/features/simulator/presentation/simulator_screen.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MisLukasApp()));
    await tester.pumpAndSettle();
  }

  Future<void> login(WidgetTester tester) async {
    await tester.tap(find.text('Entrar (temporal)'));
    await tester.pumpAndSettle();
  }

  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomNav),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('arranca en /login y desde ahí llega a /home', (tester) async {
    await pumpApp(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(AppBottomNav), findsNothing);

    await login(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(AppBottomNav), findsOneWidget);
  });

  testWidgets('la barra inferior cambia entre las 4 pestañas', (tester) async {
    await pumpApp(tester);
    await login(tester);

    await tapTab(tester, 'Reportes');
    expect(find.byType(ReportsScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);

    await tapTab(tester, 'Simular');
    expect(find.byType(SimulatorScreen), findsOneWidget);

    await tapTab(tester, 'Perfil');
    expect(find.byType(ProfileScreen), findsOneWidget);

    await tapTab(tester, 'Inicio');
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('/movements/new se abre sin barra inferior', (tester) async {
    await pumpApp(tester);
    await login(tester);

    await tester.tap(find.text('Nuevo gasto'));
    await tester.pumpAndSettle();

    expect(find.byType(NewMovementScreen), findsOneWidget);
    expect(find.byType(AppBottomNav), findsNothing);

    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(AppBottomNav), findsOneWidget);
  });

  testWidgets('guardar desde confirmación vuelve a /home con el mensaje', (
    tester,
  ) async {
    await pumpApp(tester);
    await login(tester);

    await tester.tap(find.text('Nuevo gasto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Foto del recibo'));
    await tester.pumpAndSettle();

    expect(find.byType(ConfirmMovementScreen), findsOneWidget);
    expect(find.text('Método: Foto del recibo'), findsOneWidget);

    await tester.tap(find.text('Guardar gasto'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(AppBottomNav), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('Gasto guardado'),
      ),
      findsOneWidget,
    );
  });
}
