import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/security/device_authenticator.dart';
import 'package:mislukas/core/security/external_activity_tracker.dart';
import 'package:mislukas/features/auth/presentation/account_session_controller.dart';
import 'package:mislukas/features/auth/presentation/app_lock/app_lock_controller.dart';
import 'package:mislukas/features/auth/presentation/password_recovery_flow.dart';

import '../../../../helpers/fake_app_lock.dart';
import '../../../../helpers/fake_auth_repository.dart';
import '../../../../helpers/test_container.dart';
import '../../../../helpers/test_session.dart';

void main() {
  /// Contenedor con la usuaria de pruebas con sesión (o sin ella) y el
  /// bloqueo activo o no al abrir la app.
  Future<(ProviderContainer, TestSession, FakeAuthRepository)> setUpLock({
    bool enabled = true,
    bool signedIn = true,
    bool hasLock = true,
  }) async {
    final auth = FakeAuthRepository(signedInAs: signedIn ? testUser : null);
    final session = TestSession(
      initialOwner: testUser.id,
      appLockStore: MemoryAppLockStore(enabled: enabled),
      authenticator: FakeDeviceAuthenticator(hasLock: hasLock),
    );
    final (container, _) = await createTestContainer(
      seed: false,
      auth: auth,
      session: session,
    );
    container.listen(appLockProvider, (_, _) {});
    return (container, session, auth);
  }

  AppLockState stateOf(ProviderContainer c) => c.read(appLockProvider);
  AppLockController controllerOf(ProviderContainer c) =>
      c.read(appLockProvider.notifier);

  /// La app pasa [away] en segundo plano (los dos relojes avanzan igual).
  Future<void> background(
    ProviderContainer c,
    TestSession session,
    Duration away,
  ) async {
    controllerOf(c).onHide();
    session.lockClock.advance(away);
    await controllerOf(c).onResume();
    await pumpEventQueue();
  }

  group('arranque en frío', () {
    test('con el bloqueo activo y sesión, no se ve nada', () async {
      final (container, session, _) = await setUpLock();
      expect(stateOf(container).locked, isTrue);
      expect(stateOf(container).contentVisible, isFalse);

      session.authenticator.nextResults.add(DeviceAuthResult.success);
      await controllerOf(container).engage();

      expect(session.authenticator.prompts, [AppLockController.unlockReason]);
      expect(stateOf(container).contentVisible, isTrue);
    });

    test('sin el bloqueo activo, la app se ve', () async {
      final (container, session, _) = await setUpLock(enabled: false);
      await controllerOf(container).engage();
      expect(stateOf(container).contentVisible, isTrue);
      expect(session.authenticator.prompts, isEmpty);
    });

    test('sin sesión no hay bloqueo', () async {
      final (container, session, _) = await setUpLock(signedIn: false);
      await controllerOf(container).engage();
      expect(stateOf(container).contentVisible, isTrue);
      expect(session.authenticator.prompts, isEmpty);
    });
  });

  group('tiempo en segundo plano', () {
    Future<(ProviderContainer, TestSession)> unlocked() async {
      final (container, session, _) = await setUpLock();
      await controllerOf(container).engage();
      expect(stateOf(container).contentVisible, isTrue);
      session.authenticator.prompts.clear();
      return (container, session);
    }

    test('4:59 no bloquea', () async {
      final (container, session) = await unlocked();
      await background(
        container,
        session,
        const Duration(minutes: 4, seconds: 59),
      );
      expect(stateOf(container).contentVisible, isTrue);
    });

    test('5:00 bloquea y muestra el diálogo del sistema', () async {
      final (container, session) = await unlocked();
      session.authenticator.nextResults.add(DeviceAuthResult.canceled);
      await background(container, session, const Duration(minutes: 5));
      expect(stateOf(container).locked, isTrue);
      expect(stateOf(container).contentVisible, isFalse);
      expect(session.authenticator.prompts, hasLength(1));
    });

    test('5:00 solo en el reloj monotónico bloquea', () async {
      final (container, session) = await unlocked();
      controllerOf(container).onHide();
      session.lockClock.advanceMonotonic(const Duration(minutes: 5));
      await controllerOf(container).onResume();
      expect(stateOf(container).locked, isTrue);
    });

    test('celular dormido: monotónico bajo y hora del sistema alta '
        'bloquea', () async {
      final (container, session) = await unlocked();
      controllerOf(container).onHide();
      session.lockClock
        ..advanceMonotonic(const Duration(minutes: 1))
        ..advanceWall(const Duration(hours: 1));
      await controllerOf(container).onResume();
      expect(stateOf(container).locked, isTrue);
    });

    test('la hora del sistema que retrocede bloquea', () async {
      final (container, session) = await unlocked();
      controllerOf(container).onHide();
      session.lockClock
        ..advanceMonotonic(const Duration(seconds: 10))
        ..advanceWall(const Duration(minutes: -1));
      await controllerOf(container).onResume();
      expect(stateOf(container).locked, isTrue);
    });
  });

  group('acciones de la propia app', () {
    Future<(ProviderContainer, TestSession, ExternalActivityTracker)>
    unlocked() async {
      final (container, session, _) = await setUpLock();
      await controllerOf(container).engage();
      // Si se bloquea, el diálogo del sistema se cancela.
      session.authenticator.nextResults.add(DeviceAuthResult.canceled);
      return (
        container,
        session,
        container.read(externalActivityTrackerProvider),
      );
    }

    test('la galería o el permiso (run) suben el límite a 30 min', () async {
      final (container, session, tracker) = await unlocked();
      await tracker.run(() async {
        controllerOf(container).onHide();
        session.lockClock.advance(const Duration(minutes: 29));
      });
      await controllerOf(container).onResume();
      expect(stateOf(container).contentVisible, isTrue);

      await tracker.run(() async {
        controllerOf(container).onHide();
        session.lockClock.advance(const Duration(minutes: 30));
      });
      await controllerOf(container).onResume();
      expect(stateOf(container).locked, isTrue);
    });

    test('Ajustes: 29 min no bloquea y 31 min bloquea', () async {
      final (container, session, tracker) = await unlocked();
      tracker.markLeavingForSettings();
      await background(container, session, const Duration(minutes: 29));
      expect(stateOf(container).contentVisible, isTrue);

      tracker.markLeavingForSettings();
      await background(container, session, const Duration(minutes: 31));
      expect(stateOf(container).locked, isTrue);
    });

    test('Ajustes cuenta solo para la siguiente salida', () async {
      final (container, session, tracker) = await unlocked();
      tracker.markLeavingForSettings();
      await background(container, session, const Duration(seconds: 30));
      // La siguiente salida es normal: 5 min bloquean.
      await background(container, session, const Duration(minutes: 6));
      expect(stateOf(container).locked, isTrue);
    });

    test('Ajustes no cuenta si la app no salió enseguida', () async {
      final (container, session, tracker) = await unlocked();
      tracker.markLeavingForSettings();
      session.lockClock.advance(const Duration(minutes: 1));
      await background(container, session, const Duration(minutes: 6));
      expect(stateOf(container).locked, isTrue);
    });

    test('el diálogo del sistema no vuelve a bloquear al volver', () async {
      final (container, session, _) = await setUpLock();
      // El PIN del celular abre otra pantalla: la app sale y vuelve.
      session.authenticator.onPrompt = () {
        controllerOf(container).onHide();
        session.lockClock.advance(const Duration(minutes: 6));
        controllerOf(container).onResume();
      };
      await controllerOf(container).engage();
      await pumpEventQueue();
      expect(stateOf(container).contentVisible, isTrue);
      expect(session.authenticator.prompts, hasLength(1));
    });
  });

  group('respuestas del diálogo del sistema', () {
    test('cancelar deja la app bloqueada y no insiste', () async {
      final (container, session, _) = await setUpLock();
      session.authenticator.nextResults.add(DeviceAuthResult.canceled);
      await controllerOf(container).engage();

      expect(stateOf(container).contentVisible, isFalse);
      expect(stateOf(container).message, AppLockMessage.canceled);
      await controllerOf(container).onResume();
      expect(session.authenticator.prompts, hasLength(1));

      // "Ingresar con huella, rostro o PIN" lo vuelve a mostrar.
      await controllerOf(container).unlock();
      expect(stateOf(container).contentVisible, isTrue);
      expect(stateOf(container).message, isNull);
    });

    test('bloqueo temporal del sistema por intentos', () async {
      final (container, session, _) = await setUpLock();
      session.authenticator.nextResults.add(DeviceAuthResult.lockedOut);
      await controllerOf(container).engage();
      expect(stateOf(container).contentVisible, isFalse);
      expect(stateOf(container).message, AppLockMessage.lockedOut);
    });

    test('si el sistema cierra el diálogo, se repite al volver', () async {
      final (container, session, _) = await setUpLock();
      session.authenticator.nextResults.add(DeviceAuthResult.interrupted);
      await controllerOf(container).engage();
      expect(stateOf(container).contentVisible, isFalse);

      await background(container, session, const Duration(seconds: 5));
      expect(session.authenticator.prompts, hasLength(2));
      expect(stateOf(container).contentVisible, isTrue);
    });
  });

  group('celular sin bloqueo de pantalla', () {
    test('la protección se pausa y se reanuda sola', () async {
      final (container, session, _) = await setUpLock(hasLock: false);
      await controllerOf(container).engage();
      expect(stateOf(container).enabled, isTrue);
      expect(stateOf(container).deviceLockAvailable, isFalse);
      expect(stateOf(container).contentVisible, isTrue);
      expect(session.authenticator.prompts, isEmpty);

      // El usuario vuelve a poner un bloqueo de pantalla: se revisa en el
      // próximo bloqueo.
      session.authenticator.hasLock = true;
      await controllerOf(container).onResume();
      expect(stateOf(container).contentVisible, isTrue);
      session.authenticator.nextResults.add(DeviceAuthResult.canceled);
      await background(container, session, const Duration(minutes: 6));
      expect(stateOf(container).contentVisible, isFalse);
      expect(session.authenticator.prompts, hasLength(1));
    });

    test('si el sistema dice que no hay bloqueo al autenticar', () async {
      final (container, session, _) = await setUpLock();
      session.authenticator.nextResults.add(DeviceAuthResult.noDeviceLock);
      await controllerOf(container).engage();
      expect(stateOf(container).deviceLockAvailable, isFalse);
      expect(stateOf(container).contentVisible, isTrue);
    });
  });

  group('inicio de sesión', () {
    test('iniciar sesión deja la app desbloqueada y sin oferta si ya estaba '
        'activo', () async {
      final (container, session, auth) = await setUpLock(signedIn: false);
      await auth.signIn(email: testUser.email, password: 'Clave123*');
      await pumpEventQueue();

      expect(stateOf(container).enabled, isTrue);
      expect(stateOf(container).contentVisible, isTrue);
      expect(stateOf(container).offerPending, isFalse);
      expect(session.authenticator.prompts, isEmpty);
    });

    test('con el bloqueo apagado, queda la oferta', () async {
      final (container, session, auth) = await setUpLock(
        enabled: false,
        signedIn: false,
      );
      await auth.signIn(email: testUser.email, password: 'Clave123*');
      await pumpEventQueue();
      expect(stateOf(container).offerPending, isTrue);

      // "Activar" de la oferta no abre el diálogo del sistema.
      expect(await controllerOf(container).enableAfterSignIn(), isTrue);
      expect(session.authenticator.prompts, isEmpty);
      expect(session.appLockStore.enabled, isTrue);
      expect(stateOf(container).enabled, isTrue);
      expect(stateOf(container).contentVisible, isTrue);
      expect(stateOf(container).offerPending, isFalse);
    });

    test('la recuperación de contraseña no cuenta como inicio de '
        'sesión', () async {
      final (container, session, auth) = await setUpLock(
        enabled: false,
        signedIn: false,
      );
      container.listen(accountSessionProvider, (_, _) {});
      await container.read(passwordRecoveryInProgressProvider.notifier).start();
      await auth.verifyRecoveryCode(email: testUser.email, code: '123456');
      await pumpEventQueue();

      expect(
        container.read(accountSessionProvider),
        AccountSessionStatus.signedOut,
      );
      expect(stateOf(container).hasSession, isFalse);
      expect(stateOf(container).offerPending, isFalse);
      expect(session.authenticator.prompts, isEmpty);
    });

    test('al cerrar sesión no queda nada bloqueado', () async {
      final (container, _, auth) = await setUpLock();
      await auth.signOut();
      await pumpEventQueue();
      expect(stateOf(container).hasSession, isFalse);
      expect(stateOf(container).contentVisible, isTrue);
    });

    test('el borrado total quita la preferencia: al volver a entrar se '
        'ofrece activarla y el regreso no pide desbloquear', () async {
      final (container, session, auth) = await setUpLock();
      await controllerOf(container).engage();
      session.authenticator.prompts.clear();

      await auth.signOut();
      await session.wiper.wipe();
      await auth.signIn(email: testUser.email, password: 'Clave123*');
      await pumpEventQueue();

      expect(session.appLockStore.enabled, isFalse);
      expect(stateOf(container).enabled, isFalse);
      expect(stateOf(container).offerPending, isTrue);
      expect(stateOf(container).contentVisible, isTrue);
      expect(session.authenticator.prompts, isEmpty);

      await background(container, session, const Duration(minutes: 5));
      expect(stateOf(container).contentVisible, isTrue);
      expect(session.authenticator.prompts, isEmpty);
    });
  });

  group('desactivar', () {
    test('pide el diálogo del sistema', () async {
      final (container, session, _) = await setUpLock();
      await controllerOf(container).engage();
      session.authenticator.nextResults.add(DeviceAuthResult.canceled);
      expect(
        await controllerOf(container).disable(),
        DeviceAuthResult.canceled,
      );
      expect(session.appLockStore.enabled, isTrue);

      expect(await controllerOf(container).disable(), DeviceAuthResult.success);
      expect(session.appLockStore.enabled, isFalse);
      expect(stateOf(container).enabled, isFalse);
      expect(
        session.authenticator.prompts.last,
        AppLockController.disableReason,
      );
    });
  });
}
