import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/widgets/widgets.dart';
import 'package:mislukas/features/auth/domain/entities/auth_user.dart';
import 'package:mislukas/features/auth/presentation/account_session_controller.dart';
import 'package:mislukas/features/auth/presentation/login_screen.dart';
import 'package:mislukas/features/auth/presentation/verify_email_screen.dart';
import 'package:mislukas/features/auth/presentation/widgets/foreign_data_prompt.dart';
import 'package:mislukas/features/home/presentation/home_screen.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/pump_screen.dart';
import '../../../helpers/test_database.dart';
import '../../../helpers/test_session.dart';

/// Cuenta A: la dueña de los datos del celular al empezar.
const AuthUser accountA = AuthUser(
  id: '00000000-0000-4000-8000-00000000000a',
  email: 'cuenta.a@ejemplo.com',
  name: 'Cuenta A',
);

/// Cuenta B: la que entra después (registro o login).
const AuthUser accountB = AuthUser(
  id: '00000000-0000-4000-8000-00000000000b',
  email: 'cuenta.b@ejemplo.com',
  name: 'Cuenta B',
);

/// Cambio de cuenta en el mismo celular con la app completa (router,
/// controlador de la sesión y sincronización con el servidor falso).
void main() {
  Finder input(String label) => find.descendant(
    of: find.ancestor(
      of: find.text(label.toUpperCase()),
      matching: find.byType(AppTextField),
    ),
    matching: find.byType(TextField),
  );

  Finder dialogButton(String label) =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text(label));

  /// A tiene sesión y es la dueña de la base (con la demo cargada).
  Future<(FakeAuthRepository, TestSession)> openAsA(
    WidgetTester tester,
    dynamic db,
  ) async {
    final auth = FakeAuthRepository(signedInAs: accountA, user: accountB);
    final session = TestSession(initialOwner: accountA.id, userId: accountA.id);
    await pumpApp(tester, database: db, auth: auth, session: session);
    expect(find.byType(HomeScreen), findsOneWidget);
    return (auth, session);
  }

  /// Cierre de sesión con el botón del Perfil (sin pendientes: el servidor
  /// falso está en línea).
  Future<void> signOutFromProfile(WidgetTester tester) async {
    await openTab(tester, 'Perfil');
    await tester.tap(find.widgetWithText(AppSecondaryButton, 'Cerrar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(dialogButton('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  }

  /// Registro de B desde el login hasta verificar el código.
  Future<void> registerAndVerifyB(WidgetTester tester) async {
    await tester.tap(find.text('Registrarse'));
    await tester.pumpAndSettle();
    await tester.enterText(input('Nombre'), 'Cuenta B');
    await tester.enterText(input('Correo electrónico'), accountB.email);
    await tester.enterText(input('Contraseña'), 'Lukas#Ahorro26');
    await tester.enterText(input('Confirmar contraseña'), 'Lukas#Ahorro26');
    await tester.pump();
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    final create = find.widgetWithText(AppPrimaryButton, 'Crear cuenta');
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(find.byType(VerifyEmailScreen), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byType(AppCodeField),
        matching: find.byType(TextField),
      ),
      '123456',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(AppPrimaryButton, 'Verificar'));
    await tester.pumpAndSettle();
  }

  testWidgetsWithDatabase(
    'cierre voluntario de A → registro de B → entra a Inicio sin aviso',
    (tester, db) async {
      final (auth, session) = await openAsA(tester, db);
      await signOutFromProfile(tester);
      expect(session.store.owner, isNull);

      await registerAndVerifyB(tester);

      expect(find.text(ForeignDataPrompt.title), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(auth.currentUser, accountB);
      expect(session.store.owner, accountB.id);
    },
  );

  testWidgetsWithDatabase(
    'cierre involuntario de A → registro de B → aviso → Continuar → Inicio '
    'vacío',
    (tester, db) async {
      final (auth, session) = await openAsA(tester, db);
      auth.setSession(null);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(session.store.owner, accountA.id);

      await registerAndVerifyB(tester);

      // Un solo aviso, aunque la verificación esté apilada sobre el login.
      expect(find.text(ForeignDataPrompt.title), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      await tester.tap(dialogButton('Continuar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Aún no tienes movimientos este mes'), findsOneWidget);
      expect(session.wiper.wipes, 1);
      expect(session.store.owner, accountB.id);
    },
  );

  testWidgetsWithDatabase(
    'cierre involuntario de A → login de B → aviso → Cancelar → login sin '
    'sesión',
    (tester, db) async {
      final (auth, session) = await openAsA(tester, db);
      auth.setSession(null);
      await tester.pumpAndSettle();

      await loginAsDemoUser(tester);

      expect(find.text(ForeignDataPrompt.title), findsOneWidget);
      await tester.tap(dialogButton('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(auth.currentUser, isNull);
      expect(session.wiper.wipes, 0);
      expect(session.store.owner, accountA.id);
    },
  );

  testWidgetsWithDatabase(
    'si el borrado se cuelga al cerrar sesión, la siguiente cuenta no queda '
    'bloqueada: ve el aviso',
    (tester, db) async {
      final (auth, session) = await openAsA(tester, db);
      session.wiper.hangNext = true;
      await signOutFromProfile(tester);

      // Pasado el tiempo máximo del borrado, el estado se recalcula.
      await tester.pump(
        AccountSessionController.wipeTimeout + const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();

      await loginAsDemoUser(tester);

      // No se pudo confirmar el borrado: los datos de A pueden seguir, así que
      // se avisa en lugar de abrirlos o quedarse en el login sin respuesta.
      expect(find.text(ForeignDataPrompt.title), findsOneWidget);
      await tester.tap(dialogButton('Continuar'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(auth.currentUser, accountB);
    },
  );

  testWidgetsWithDatabase(
    'si no se pueden borrar los datos de la otra cuenta, cierra la sesión '
    'con un mensaje',
    (tester, db) async {
      final (auth, session) = await openAsA(tester, db);
      auth.setSession(null);
      await tester.pumpAndSettle();
      session.wiper.failNext = true;

      await loginAsDemoUser(tester);
      await tester.tap(dialogButton('Continuar'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(auth.currentUser, isNull);
      expect(
        find.text(AccountNotice.foreignWipeFailed.message),
        findsOneWidget,
      );
    },
  );
}
