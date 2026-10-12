import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/widgets/widgets.dart';
import 'package:mislukas/features/auth/presentation/login_screen.dart';
import 'package:mislukas/features/profile/presentation/profile_screen.dart';
import 'package:mislukas/features/profile/presentation/profile_view_model.dart';

import '../../../helpers/pump_screen.dart';

void main() {
  Future<void> openProfile(WidgetTester tester) async {
    await pumpApp(tester);
    await loginAsDemoUser(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomNav),
        matching: find.text('Perfil'),
      ),
    );
    await tester.pumpAndSettle();
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
    expect(find.text('camila@correo.com'), findsOneWidget);
    expect(find.text('Perfil completo en una próxima versión'), findsOneWidget);
    expect(
      find.widgetWithText(AppSecondaryButton, 'Cerrar sesión'),
      findsOneWidget,
    );
  });

  testWidgets('Cerrar sesión vuelve a /login', (tester) async {
    await openProfile(tester);
    expect(find.byType(ProfileScreen), findsOneWidget);

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(AppBottomNav), findsNothing);
  });

  testWidgets('sin overflow en 320 x 640 con texto al 130%, con la barra', (
    tester,
  ) async {
    useSmallScreen(tester);
    await openProfile(tester);

    expect(find.byType(ProfileScreen), findsOneWidget);
    await expectNoOverflowWhileScrolling(tester);
    expect(find.text('Cerrar sesión').hitTestable(), findsOneWidget);
  });
}
