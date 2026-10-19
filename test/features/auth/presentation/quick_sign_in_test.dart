import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/security/device_authenticator.dart';
import 'package:mislukas/core/widgets/widgets.dart';
import 'package:mislukas/features/auth/domain/auth_failure.dart';
import 'package:mislukas/features/auth/domain/entities/auth_user.dart';
import 'package:mislukas/features/auth/presentation/app_lock/app_lock_offer_launcher.dart';
import 'package:mislukas/features/auth/presentation/app_lock/unlock_screen.dart';
import 'package:mislukas/features/auth/presentation/auth_messages.dart';
import 'package:mislukas/features/auth/presentation/login_screen.dart';
import 'package:mislukas/features/auth/presentation/quick_sign_in_view_model.dart';
import 'package:mislukas/features/auth/presentation/sign_out_messages.dart';
import 'package:mislukas/features/auth/presentation/widgets/foreign_data_prompt.dart';
import 'package:mislukas/features/auth/presentation/widgets/quick_sign_in_section.dart';
import 'package:mislukas/features/home/presentation/home_screen.dart';
import 'package:mislukas/features/profile/presentation/profile_screen.dart';

import '../../../helpers/fake_app_lock.dart';
import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/pump_screen.dart';
import '../../../helpers/test_database.dart';
import '../../../helpers/test_session.dart';

const AuthUser otherUser = AuthUser(
  id: '00000000-0000-4000-8000-000000000002',
  email: 'andres@ejemplo.com',
  name: 'Andrés',
);

/// "Ingresar con huella, rostro o PIN" en el login y el cierre de sesión que
/// conserva la sesión guardada (docs/07 §7.7, docs/08 §8.8.4), con la app
/// completa y el bloqueo del celular falso.
void main() {
  final quickButton = find.widgetWithText(
    AppSecondaryButton,
    QuickSignInSection.deviceLockLabel,
  );

  Finder dialogButton(String label) =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text(label));

  /// Sesión de la usuaria en espera: la app abre en el login.
  TestSession parkedSession({
    bool enabled = true,
    bool hasLock = true,
    String? parkedUser,
  }) => TestSession(
    store: MemoryDeviceSessionStore(
      owner: testUser.id,
      parkedUser: parkedUser ?? testUser.id,
    ),
    initialOwner: testUser.id,
    appLockStore: MemoryAppLockStore(enabled: enabled),
    authenticator: FakeDeviceAuthenticator(hasLock: hasLock),
  );

  Future<FakeAuthRepository> openLogin(
    WidgetTester tester,
    dynamic db,
    TestSession session, {
    AuthUser? signedInAs = testUser,
    AuthUser user = testUser,
  }) async {
    final auth = FakeAuthRepository(signedInAs: signedInAs, user: user);
    await pumpApp(tester, database: db, auth: auth, session: session);
    expect(find.byType(LoginScreen), findsOneWidget);
    return auth;
  }

  Future<void> tapQuickButton(WidgetTester tester) async {
    await tester.ensureVisible(quickButton);
    await tester.tap(quickButton);
    await tester.pumpAndSettle();
  }

  group('el botón', () {
    testWidgetsWithDatabase(
      'aparece con el ajuste activo, la sesión guardada y bloqueo de pantalla',
      (tester, db) async {
        final session = parkedSession();
        await openLogin(tester, db, session);
        expect(quickButton, findsOneWidget);
        expect(find.text('o'), findsOneWidget);
        // Arranque en frío con la sesión en espera: login, no desbloqueo, y
        // el diálogo del sistema no se abre solo.
        expect(find.byType(UnlockScreen), findsNothing);
        expect(session.authenticator.prompts, isEmpty);
      },
    );

    testWidgetsWithDatabase('no aparece con el ajuste apagado', (
      tester,
      db,
    ) async {
      await openLogin(tester, db, parkedSession(enabled: false));
      expect(quickButton, findsNothing);
      expect(find.text('o'), findsNothing);
    });

    testWidgetsWithDatabase('no aparece sin sesión guardada', (
      tester,
      db,
    ) async {
      await openLogin(tester, db, parkedSession(), signedInAs: null);
      expect(quickButton, findsNothing);
    });

    testWidgetsWithDatabase(
      'no aparece si la sesión guardada es de otra cuenta que la marca',
      (tester, db) async {
        // La marca es de otra cuenta: la sesión de la usuaria no está en
        // espera y la app entra directo (no hay login con el botón).
        final session = parkedSession(parkedUser: otherUser.id);
        final auth = FakeAuthRepository(signedInAs: testUser);
        await pumpApp(tester, database: db, auth: auth, session: session);
        expect(find.byType(LoginScreen), findsNothing);
        expect(find.byType(HomeScreen), findsOneWidget);
      },
    );

    testWidgetsWithDatabase('no aparece sin bloqueo de pantalla', (
      tester,
      db,
    ) async {
      await openLogin(tester, db, parkedSession(hasLock: false));
      expect(quickButton, findsNothing);
    });

    testWidgetsWithDatabase('no aparece en Registrarse', (tester, db) async {
      await openLogin(tester, db, parkedSession());
      await tester.tap(find.text('Registrarse'));
      await tester.pumpAndSettle();
      expect(quickButton, findsNothing);
    });
  });

  group('ingresar', () {
    testWidgetsWithDatabase(
      'con el diálogo del sistema entra a Inicio sin contraseña, sin oferta '
      'ni desbloqueo',
      (tester, db) async {
        final session = parkedSession();
        final auth = await openLogin(tester, db, session);

        await tapQuickButton(tester);

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.byType(UnlockScreen), findsNothing);
        expect(find.text(AppLockOfferLauncher.title), findsNothing);
        expect(session.authenticator.prompts, [QuickSignInViewModel.reason]);
        expect(auth.calls, ['resumeSession']);
        expect(session.store.parkedUser, isNull);
        expect(session.wiper.wipes, 0);
      },
    );

    testWidgetsWithDatabase('si cancela el diálogo sigue en el login', (
      tester,
      db,
    ) async {
      final session = parkedSession();
      final auth = await openLogin(tester, db, session);
      session.authenticator.nextResults.add(DeviceAuthResult.canceled);

      await tapQuickButton(tester);

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text(UnlockScreen.canceledMessage), findsOneWidget);
      expect(quickButton, findsOneWidget);
      expect(auth.calls, isEmpty);
      expect(session.store.parkedUser, testUser.id);
    });

    testWidgetsWithDatabase('sin conexión para renovar la sesión, entra igual', (
      tester,
      db,
    ) async {
      final session = parkedSession();
      final auth = await openLogin(tester, db, session);
      auth.failNext(AuthFailure.network);

      await tapQuickButton(tester);

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(session.store.parkedUser, isNull);
    });

    testWidgetsWithDatabase(
      'con la sesión vencida o revocada pide la contraseña y conserva los '
      'datos',
      (tester, db) async {
        final session = parkedSession();
        final auth = await openLogin(tester, db, session);
        auth.failNext(AuthFailure.sessionExpired);

        await tapQuickButton(tester);

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.text(sessionExpiredMessage), findsOneWidget);
        expect(quickButton, findsNothing);
        expect(auth.currentUser, isNull);
        expect(session.store.parkedUser, isNull);
        // Regla de la sesión revocada (docs/06 §6.6.4): nada se borra.
        expect(session.wiper.wipes, 0);
        expect(session.store.owner, testUser.id);
        expect(session.appLockStore.enabled, isTrue);

        // Con su contraseña vuelve a sus datos, sin aviso de otra cuenta.
        await loginAsDemoUser(tester);
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.text(ForeignDataPrompt.title), findsNothing);
        expect(session.wiper.wipes, 0);
      },
    );

    testWidgetsWithDatabase(
      'con la contraseña de la misma cuenta también entra y quita la espera',
      (tester, db) async {
        final session = parkedSession();
        await openLogin(tester, db, session);

        await loginAsDemoUser(tester);

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.text(ForeignDataPrompt.title), findsNothing);
        expect(session.store.parkedUser, isNull);
        expect(session.wiper.wipes, 0);
      },
    );
  });

  group('otra cuenta en el mismo celular', () {
    testWidgetsWithDatabase(
      'entra con su contraseña: aviso de datos de otra cuenta; al aceptar se '
      'borran los datos, la espera y la preferencia',
      (tester, db) async {
        final session = parkedSession();
        await openLogin(tester, db, session, user: otherUser);

        await loginAsDemoUser(tester);

        expect(find.text(ForeignDataPrompt.title), findsOneWidget);
        // La sesión guardada de la usuaria se reemplazó: ya no hay espera.
        expect(session.store.parkedUser, isNull);
        await tester.tap(dialogButton('Continuar'));
        await tester.pumpAndSettle();

        expect(session.wiper.wipes, 1);
        expect(session.store.owner, otherUser.id);
        expect(session.appLockStore.enabled, isFalse);
        expect(find.byType(HomeScreen), findsOneWidget);
      },
    );

    testWidgetsWithDatabase(
      'si no acepta, vuelve al login sin botón y los datos de la usuaria '
      'siguen en el celular',
      (tester, db) async {
        final session = parkedSession();
        await openLogin(tester, db, session, user: otherUser);

        await loginAsDemoUser(tester);
        await tester.tap(dialogButton('Cancelar'));
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(quickButton, findsNothing);
        expect(session.wiper.wipes, 0);
        expect(session.store.owner, testUser.id);
      },
    );
  });

  group('cerrar sesión desde el Perfil', () {
    /// La usuaria con sesión; con el ajuste activo, el arranque en frío pasa
    /// el diálogo del sistema (responde éxito).
    Future<(FakeAuthRepository, TestSession)> openProfile(
      WidgetTester tester,
      dynamic db, {
      bool enabled = true,
    }) async {
      final session = TestSession(
        initialOwner: testUser.id,
        appLockStore: MemoryAppLockStore(enabled: enabled),
        authenticator: FakeDeviceAuthenticator(),
      );
      final auth = FakeAuthRepository(signedInAs: testUser);
      await pumpApp(tester, database: db, auth: auth, session: session);
      if (!enabled) {
        // Sin el ajuste se ofrece activarlo al iniciar sesión, no al abrir.
        expect(find.text(AppLockOfferLauncher.title), findsNothing);
      }
      await openTab(tester, 'Perfil');
      final button = find.widgetWithText(AppSecondaryButton, 'Cerrar sesión');
      await tester.scrollUntilVisible(
        button,
        200,
        scrollable: find
            .descendant(
              of: find.byType(ProfileScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      return (auth, session);
    }

    testWidgetsWithDatabase(
      'con el ajuste activo, "Cerrar sesión" conserva la sesión y los datos; '
      'el botón del login vuelve a entrar',
      (tester, db) async {
        final (auth, session) = await openProfile(tester, db);
        session.server.offline = true;
        expect(find.text(keepSessionSignOutMessage), findsOneWidget);

        await tester.tap(dialogButton(signOutLabel));
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);
        // Sin pendientes que confirmar: nada se pierde.
        expect(find.text(unsyncedSignOutTitle), findsNothing);
        expect(auth.calls, isNot(contains('signOut')));
        expect(auth.currentUser, testUser);
        expect(session.wiper.wipes, 0);
        expect(session.store.parkedUser, testUser.id);
        expect(quickButton, findsOneWidget);

        await tapQuickButton(tester);
        expect(find.byType(HomeScreen), findsOneWidget);
      },
    );

    testWidgetsWithDatabase(
      'con el ajuste activo, "borrar los datos" hace el borrado total',
      (tester, db) async {
        final (auth, session) = await openProfile(tester, db);

        await tester.tap(dialogButton(wipeSignOutLabel));
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(auth.calls, contains('signOut'));
        expect(session.wiper.wipes, 1);
        expect(session.store.parkedUser, isNull);
        expect(session.appLockStore.enabled, isFalse);
        expect(quickButton, findsNothing);
      },
    );

    testWidgetsWithDatabase(
      'con el ajuste apagado solo hay borrado total, como antes',
      (tester, db) async {
        final (auth, session) = await openProfile(tester, db, enabled: false);
        expect(find.text(signOutConfirmMessage), findsOneWidget);
        expect(dialogButton(wipeSignOutLabel), findsNothing);

        await tester.tap(dialogButton(signOutLabel));
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(auth.calls, contains('signOut'));
        expect(session.wiper.wipes, 1);
        expect(session.store.parkedUser, isNull);
      },
    );

    testWidgetsWithDatabase(
      'si no se puede guardar la espera, no cierra la sesión',
      (tester, db) async {
        final (auth, session) = await openProfile(tester, db);
        session.store.failNextParkedWrite = true;

        await tester.tap(dialogButton(signOutLabel));
        await tester.pumpAndSettle();

        expect(find.byType(ProfileScreen), findsOneWidget);
        expect(find.text(authMessageFor(AuthFailure.unknown)), findsOneWidget);
        expect(session.store.parkedUser, isNull);
        expect(auth.calls, isNot(contains('signOut')));
        expect(session.wiper.wipes, 0);
      },
    );
  });
}
