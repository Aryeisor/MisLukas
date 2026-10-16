import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/database/seed/demo_seed.dart';
import 'package:mislukas/core/database/app_database.dart';
import 'package:mislukas/core/widgets/dev/demo_data_actions.dart';
import 'package:mislukas/core/widgets/widgets.dart';
import 'package:mislukas/features/auth/presentation/login_screen.dart';
import 'package:mislukas/features/profile/presentation/profile_screen.dart';
import 'package:mislukas/features/profile/presentation/profile_view_model.dart';

import '../../../helpers/pump_screen.dart';
import '../../../helpers/test_database.dart';

void main() {
  Future<void> openProfile(WidgetTester tester, AppDatabase db) async {
    await pumpApp(tester, database: db);
    await loginAsDemoUser(tester);
    await openTab(tester, 'Perfil');
  }

  test('initialsOf toma nombre y apellido', () {
    expect(initialsOf('Camila Rodríguez'), 'CR');
    expect(initialsOf('  ana  maría pérez '), 'AM');
    expect(initialsOf('camila'), 'C');
    expect(initialsOf(''), '');
  });

  testWidgets('muestra los datos de la usuaria', (tester) async {
    await pumpScreen(tester, const ProfileScreen());

    expect(find.text('CR'), findsOneWidget);
    expect(find.text('Camila Rodríguez'), findsOneWidget);
    expect(find.text('camila@ejemplo.com'), findsOneWidget);
    expect(find.text('Perfil completo en una próxima versión'), findsOneWidget);
    expect(
      find.widgetWithText(AppSecondaryButton, 'Cerrar sesión'),
      findsOneWidget,
    );
  });

  testWidgets('en modo desarrollo muestra las acciones de demo', (
    tester,
  ) async {
    await pumpScreen(tester, const ProfileScreen());

    expect(find.text('Herramientas de desarrollo'), findsOneWidget);
    expect(find.text('Cargar datos de demostración'), findsOneWidget);
    final clear = tester.widget<AppSecondaryButton>(
      find.widgetWithText(AppSecondaryButton, 'Borrar todos los datos'),
    );
    expect(clear.destructive, isTrue);
  });

  testWidgets('fuera de modo desarrollo no existen las acciones de demo', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const ProfileScreen(),
      overrides: [demoToolsEnabledProvider.overrideWithValue(false)],
    );

    expect(find.byType(DemoDataActions), findsNothing);
    expect(find.text('Cargar datos de demostración'), findsNothing);
    expect(find.text('Borrar todos los datos'), findsNothing);
    expect(find.text('Cerrar sesión'), findsOneWidget);
  });

  testWidgetsWithDatabase('Cerrar sesión vuelve a /login', (tester, db) async {
    await openProfile(tester, db);
    expect(find.byType(ProfileScreen), findsOneWidget);

    await tester.tap(find.widgetWithText(AppSecondaryButton, 'Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('¿Cerrar sesión?'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Cerrar sesión'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(AppBottomNav), findsNothing);
  });

  testWidgetsWithDatabase('Cancelar no cierra la sesión', (tester, db) async {
    await openProfile(tester, db);

    await tester.tap(find.widgetWithText(AppSecondaryButton, 'Cerrar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
  });

  testWidgetsWithDatabase(
    'sin overflow en 320 x 640 con texto al 130%, con la barra',
    (tester, db) async {
      useSmallScreen(tester);
      await openProfile(tester, db);

      expect(find.byType(ProfileScreen), findsOneWidget);
      await expectNoOverflowWhileScrolling(tester);
      expect(find.text('Borrar todos los datos').hitTestable(), findsOneWidget);
    },
  );
}
