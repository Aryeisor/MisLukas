import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/widgets/widgets.dart';
import 'package:mislukas/features/auth/presentation/login_screen.dart';
import 'package:mislukas/features/home/presentation/home_screen.dart';
import 'package:mislukas/features/movements/presentation/confirm_movement_screen.dart';
import 'package:mislukas/features/movements/presentation/new_movement_screen.dart';
import 'package:mislukas/features/profile/presentation/profile_screen.dart';
import 'package:mislukas/features/reports/presentation/reports_screen.dart';
import 'package:mislukas/features/simulator/presentation/simulator_screen.dart';

import '../../helpers/pump_screen.dart';
import '../../helpers/test_database.dart';

void main() {
  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomNav),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgetsWithDatabase('arranca en /login y desde ahí llega a /home', (
    tester,
    db,
  ) async {
    await pumpApp(tester, database: db);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(AppBottomNav), findsNothing);

    await loginAsDemoUser(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(AppBottomNav), findsOneWidget);
  });

  testWidgetsWithDatabase('la barra inferior cambia entre las 4 pestañas', (
    tester,
    db,
  ) async {
    await pumpApp(tester, database: db);
    await loginAsDemoUser(tester);

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

  testWidgetsWithDatabase('/movements/new se abre sin barra inferior', (
    tester,
    db,
  ) async {
    await pumpApp(tester, database: db);
    await loginAsDemoUser(tester);

    await tester.tap(find.text('Nuevo gasto'));
    await tester.pumpAndSettle();

    expect(find.byType(NewMovementScreen), findsOneWidget);
    expect(find.byType(AppBottomNav), findsNothing);

    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(AppBottomNav), findsOneWidget);
  });

  testWidgetsWithDatabase(
    'Continuar abre la confirmación con el método elegido',
    (tester, db) async {
      await pumpApp(tester, database: db);
      await loginAsDemoUser(tester);

      await tester.tap(find.text('Nuevo gasto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(find.byType(ConfirmMovementScreen), findsOneWidget);
      expect(find.text('Confirma los datos'), findsOneWidget);
      expect(find.byType(AppBottomNav), findsNothing);
    },
  );

  testWidgetsWithDatabase(
    'tocar un movimiento abre su edición sin barra inferior',
    (tester, db) async {
      await pumpApp(tester, database: db);
      await loginAsDemoUser(tester);

      final tile = find.byType(MovementTile).first;
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(find.byType(ConfirmMovementScreen), findsOneWidget);
      expect(find.text('Editar movimiento'), findsOneWidget);
      expect(find.byType(AppBottomNav), findsNothing);

      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );
}
