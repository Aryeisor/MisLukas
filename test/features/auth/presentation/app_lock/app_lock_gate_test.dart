import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/app.dart';
import 'package:mislukas/core/database/app_database.dart';
import 'package:mislukas/core/notifications/local_notifications.dart';
import 'package:mislukas/core/router/app_routes.dart';
import 'package:mislukas/core/security/device_authenticator.dart';
import 'package:mislukas/core/sync/sync_controller.dart';
import 'package:mislukas/core/widgets/widgets.dart';
import 'package:mislukas/features/auth/domain/entities/auth_user.dart';
import 'package:mislukas/features/auth/presentation/app_lock/app_lock_controller.dart';
import 'package:mislukas/features/auth/presentation/app_lock/app_lock_gate.dart';
import 'package:mislukas/features/auth/presentation/app_lock/app_lock_offer_launcher.dart';
import 'package:mislukas/features/auth/presentation/app_lock/unlock_screen.dart';
import 'package:mislukas/features/auth/presentation/login_screen.dart';
import 'package:mislukas/features/auth/presentation/sign_out_messages.dart';
import 'package:mislukas/features/auth/presentation/widgets/foreign_data_prompt.dart';
import 'package:mislukas/features/auth/presentation/widgets/quick_sign_in_section.dart';
import 'package:mislukas/features/budgets/presentation/budgets_screen.dart';
import 'package:mislukas/features/home/presentation/home_screen.dart';
import 'package:mislukas/features/onboarding/presentation/welcome_screen.dart';

import '../../../../helpers/fake_app_lock.dart';
import '../../../../helpers/fake_auth_repository.dart';
import '../../../../helpers/pump_screen.dart';
import '../../../../helpers/test_database.dart';
import '../../../../helpers/test_session.dart';

/// Notificaciones con el toque simulado: [launch] abrió la app y [tap]
/// llega con la app abierta.
class FakeLocalNotifications extends LocalNotifications {
  FakeLocalNotifications({this.launch});

  String? launch;
  final StreamController<String> _taps = StreamController.broadcast();

  void tap(String payload) => _taps.add(payload);

  @override
  String? takeLaunchPayload() {
    final payload = launch;
    launch = null;
    return payload;
  }

  @override
  Stream<String> get taps => _taps.stream;
}

const AuthUser otherUser = AuthUser(
  id: '00000000-0000-4000-8000-000000000002',
  email: 'andres@ejemplo.com',
  name: 'Andrés',
);

void main() {
  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(MisLukasApp)));

  /// Sesión con el bloqueo activo; el diálogo del sistema del arranque se
  /// cancela, así la app queda en la pantalla de desbloqueo.
  TestSession lockedSession({String? owner}) {
    final session = TestSession(
      initialOwner: owner ?? testUser.id,
      appLockStore: MemoryAppLockStore(enabled: true),
      authenticator: FakeDeviceAuthenticator(),
    );
    session.authenticator.nextResults.add(DeviceAuthResult.canceled);
    return session;
  }

  Future<void> openLocked(
    WidgetTester tester,
    AppDatabase db,
    TestSession session, {
    AuthUser user = testUser,
    LocalNotifications? notifications,
  }) async {
    await pumpApp(
      tester,
      database: db,
      auth: FakeAuthRepository(signedInAs: user, user: user),
      session: session,
      overrides: [
        if (notifications != null)
          localNotificationsProvider.overrideWithValue(notifications),
      ],
    );
  }

  Future<void> tapUnlock(WidgetTester tester) async {
    await tester.tap(
      find.widgetWithText(AppPrimaryButton, UnlockScreen.unlockLabel),
    );
    await tester.pumpAndSettle();
  }

  Finder dialogButton(String label) =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text(label));

  testWidgetsWithDatabase('al abrir en frío no se ve nada hasta desbloquear', (
    tester,
    db,
  ) async {
    final session = lockedSession();
    await openLocked(tester, db, session);

    expect(find.byType(UnlockScreen), findsOneWidget);
    expect(find.text('Hola, Camila'), findsOneWidget);
    expect(
      find.widgetWithText(
        AppPrimaryButton,
        'Ingresar con huella, rostro o PIN',
      ),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(AppSecondaryButton, '¿No eres tú? Cerrar sesión'),
      findsOneWidget,
    );
    expect(find.text('Desbloquear'), findsNothing);
    expect(find.text(UnlockScreen.canceledMessage), findsOneWidget);
    // Inicio está montado pero fuera de escena: no se pinta ni se lee.
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Disponible')), findsNothing);
    expect(session.authenticator.prompts, hasLength(1));

    await tapUnlock(tester);
    expect(find.byType(UnlockScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgetsWithDatabase('bloqueo temporal del sistema', (tester, db) async {
    final session = lockedSession();
    session.authenticator.nextResults
      ..clear()
      ..add(DeviceAuthResult.lockedOut);
    await openLocked(tester, db, session);
    expect(find.text(UnlockScreen.lockedOutTitle), findsOneWidget);
    expect(find.text(UnlockScreen.lockedOutMessage), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgetsWithDatabase(
    '¿No eres tú? > Cerrar sesión conserva la sesión y los datos: vuelve al '
    'login, que ofrece entrar con el bloqueo del celular',
    (tester, db) async {
      final session = lockedSession();
      final auth = FakeAuthRepository(signedInAs: testUser);
      await pumpApp(tester, database: db, auth: auth, session: session);
      expect(find.byType(UnlockScreen), findsOneWidget);

      await tester.tap(
        find.widgetWithText(AppSecondaryButton, UnlockScreen.signOutLabel),
      );
      await tester.pumpAndSettle();
      expect(find.text(keepSessionSignOutMessage), findsOneWidget);
      expect(dialogButton(wipeSignOutLabel), findsOneWidget);
      await tester.tap(dialogButton(signOutLabel));
      await tester.pumpAndSettle();

      expect(auth.calls, isNot(contains('signOut')));
      expect(session.wiper.wipes, 0);
      expect(session.store.parkedUser, testUser.id);
      expect(session.store.owner, testUser.id);
      expect(session.appLockStore.enabled, isTrue);
      expect(find.byType(UnlockScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
        find.widgetWithText(
          AppSecondaryButton,
          QuickSignInSection.deviceLockLabel,
        ),
        findsOneWidget,
      );
    },
  );

  testWidgetsWithDatabase(
    '¿No eres tú? > borrar los datos: borrado total, sin la preferencia; al '
    'volver a entrar se ofrece activarla',
    (tester, db) async {
      final session = lockedSession();
      await openLocked(tester, db, session);
      session.server.offline = true;

      await tester.tap(
        find.widgetWithText(AppSecondaryButton, UnlockScreen.signOutLabel),
      );
      await tester.pumpAndSettle();
      await tester.tap(dialogButton(wipeSignOutLabel));
      await tester.pumpAndSettle();

      // Sin conexión quedan cambios: se pide confirmar que se pierden.
      expect(find.text(unsyncedSignOutTitle), findsOneWidget);
      await tester.tap(dialogButton('Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(session.wiper.wipes, 1);
      // La preferencia acompaña a los datos: el borrado la quita.
      expect(session.appLockStore.enabled, isFalse);
      expect(session.store.parkedUser, isNull);
      expect(find.byType(UnlockScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text(QuickSignInSection.deviceLockLabel), findsNothing);

      // Vuelve a entrar con su contraseña: se le ofrece activarla de nuevo.
      session.server.offline = false;
      await loginAsDemoUser(tester);
      await pumpUntilDone(
        tester,
        containerOf(tester).read(syncControllerProvider.notifier).syncNow(),
      );
      await tester.pumpAndSettle();
      expect(find.byType(UnlockScreen), findsNothing);
      // Sin datos tras el borrado se abre la bienvenida; la oferta queda
      // pendiente hasta que se cierre.
      final lock = containerOf(tester).read(appLockProvider);
      expect(lock.enabled, isFalse);
      expect(lock.offerPending, isTrue);
      expect(session.authenticator.prompts, hasLength(1));
    },
  );

  testWidgetsWithDatabase(
    'cancelar el cierre de sesión con cambios pendientes sigue bloqueado',
    (tester, db) async {
      final session = lockedSession();
      await openLocked(tester, db, session);
      session.server.offline = true;

      await tester.tap(
        find.widgetWithText(AppSecondaryButton, UnlockScreen.signOutLabel),
      );
      await tester.pumpAndSettle();
      await tester.tap(dialogButton(wipeSignOutLabel));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('Cancelar'));
      await tester.pumpAndSettle();

      expect(session.wiper.wipes, 0);
      expect(find.byType(UnlockScreen), findsOneWidget);
    },
  );

  testWidgetsWithDatabase(
    'la capa de recientes tapa la app al pasar a inactiva',
    (tester, db) async {
      await pumpApp(
        tester,
        database: db,
        auth: FakeAuthRepository(signedInAs: testUser),
        session: TestSession(initialOwner: testUser.id),
      );
      expect(find.byType(PrivacyCover), findsNothing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.byType(PrivacyCover), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.byType(PrivacyCover), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );

  testWidgetsWithDatabase('el aviso de otra cuenta espera al desbloqueo', (
    tester,
    db,
  ) async {
    final session = lockedSession(owner: otherUser.id);
    await openLocked(tester, db, session);

    expect(find.text(ForeignDataPrompt.title), findsNothing);
    expect(
      find.text(ForeignDataPrompt.title, skipOffstage: false),
      findsNothing,
    );

    await tapUnlock(tester);
    expect(find.text(ForeignDataPrompt.title), findsOneWidget);
  });

  testWidgetsWithDatabase('la bienvenida espera al desbloqueo', (
    tester,
    db,
  ) async {
    final session = lockedSession();
    await openLocked(tester, db, session);

    // Usuario nuevo: la primera sincronización decide mostrarla.
    await pumpUntilDone(
      tester,
      containerOf(tester).read(syncControllerProvider.notifier).syncNow(),
    );
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen, skipOffstage: false), findsNothing);

    await tapUnlock(tester);
    expect(find.byType(WelcomeScreen), findsOneWidget);
  }, seed: false);

  testWidgetsWithDatabase(
    'la notificación que abrió la app pasa primero por el desbloqueo',
    (tester, db) async {
      final session = lockedSession();
      await openLocked(
        tester,
        db,
        session,
        notifications: FakeLocalNotifications(launch: AppRoutes.budgets),
      );
      expect(find.byType(BudgetsScreen, skipOffstage: false), findsNothing);

      await tapUnlock(tester);
      expect(find.byType(BudgetsScreen), findsOneWidget);
    },
  );

  testWidgetsWithDatabase(
    'tocar una notificación con la app bloqueada espera al desbloqueo',
    (tester, db) async {
      final notifications = FakeLocalNotifications();
      final session = TestSession(
        initialOwner: testUser.id,
        appLockStore: MemoryAppLockStore(enabled: true),
        authenticator: FakeDeviceAuthenticator(),
      );
      await openLocked(tester, db, session, notifications: notifications);
      expect(find.byType(HomeScreen), findsOneWidget);

      // Pasa más de 5 minutos fuera y vuelve con el toque de la notificación.
      session.authenticator.nextResults.add(DeviceAuthResult.canceled);
      final controller = containerOf(tester).read(appLockProvider.notifier);
      controller.onHide();
      session.lockClock.advance(const Duration(minutes: 6));
      notifications.tap(AppRoutes.budgets);
      await pumpUntilDone(tester, controller.onResume());
      await tester.pumpAndSettle();

      expect(find.byType(UnlockScreen), findsOneWidget);
      expect(find.byType(BudgetsScreen, skipOffstage: false), findsNothing);

      await tapUnlock(tester);
      expect(find.byType(BudgetsScreen), findsOneWidget);
    },
  );

  group('oferta después de iniciar sesión', () {
    Future<TestSession> loginAndSync(
      WidgetTester tester,
      AppDatabase db, {
      bool hasLock = true,
    }) async {
      final session = TestSession(
        authenticator: FakeDeviceAuthenticator(hasLock: hasLock),
      );
      await pumpApp(tester, database: db, session: session);
      await loginAsDemoUser(tester);
      // El usuario tiene datos: la bienvenida no hace falta.
      await pumpUntilDone(
        tester,
        containerOf(tester).read(syncControllerProvider.notifier).syncNow(),
      );
      await tester.pumpAndSettle();
      return session;
    }

    testWidgetsWithDatabase('Activar no abre el diálogo del sistema', (
      tester,
      db,
    ) async {
      final session = await loginAndSync(tester, db);
      expect(find.text(AppLockOfferLauncher.title), findsOneWidget);

      await tester.tap(dialogButton('Activar'));
      await tester.pumpAndSettle();

      expect(session.authenticator.prompts, isEmpty);
      expect(session.appLockStore.enabled, isTrue);
      expect(
        find.text(
          'Listo. La próxima vez entrarás con tu huella, rostro o el PIN de '
          'tu celular.',
        ),
        findsOneWidget,
      );
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(UnlockScreen), findsNothing);
    });

    testWidgetsWithDatabase('Ahora no no vuelve a preguntar', (
      tester,
      db,
    ) async {
      final session = await loginAndSync(tester, db);
      await tester.tap(dialogButton('Ahora no'));
      await tester.pumpAndSettle();

      await pumpUntilDone(
        tester,
        containerOf(tester).read(syncControllerProvider.notifier).syncNow(),
      );
      await tester.pumpAndSettle();
      expect(find.text(AppLockOfferLauncher.title), findsNothing);
      expect(session.appLockStore.enabled, isFalse);
      expect(session.authenticator.prompts, isEmpty);
    });

    testWidgetsWithDatabase('sin bloqueo de pantalla no se ofrece', (
      tester,
      db,
    ) async {
      await loginAndSync(tester, db, hasLock: false);
      expect(find.text(AppLockOfferLauncher.title), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgetsWithDatabase('se ofrece después de la bienvenida', (
      tester,
      db,
    ) async {
      await loginAndSync(tester, db);
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text(AppLockOfferLauncher.title), findsNothing);

      // Omitir el paso 1 y luego el 2 termina la bienvenida.
      for (var step = 0; step < 2; step++) {
        final skip = find.widgetWithText(AppSecondaryButton, 'Omitir');
        await tester.ensureVisible(skip);
        await tester.pumpAndSettle();
        await tester.tap(skip);
        await tester.pumpAndSettle();
      }

      expect(find.byType(WelcomeScreen), findsNothing);
      expect(find.text(AppLockOfferLauncher.title), findsOneWidget);
    }, seed: false);
  });
}
