import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/database/database_providers.dart';
import 'package:mislukas/core/sync/sync_controller.dart';
import 'package:mislukas/features/auth/domain/auth_failure.dart';
import 'package:mislukas/features/auth/domain/entities/auth_user.dart';
import 'package:mislukas/features/auth/presentation/account_session_controller.dart';
import 'package:mislukas/features/auth/presentation/password_recovery_flow.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/test_container.dart';
import '../../../helpers/test_session.dart';

const AuthUser otherUser = AuthUser(
  id: '00000000-0000-4000-8000-000000000002',
  email: 'andres@ejemplo.com',
  name: 'Andrés',
);

void main() {
  /// Contenedor con la demo cargada. Mantiene vivo el controlador de la
  /// sincronización, como la app.
  Future<(ProviderContainer, FakeAuthRepository, TestSession)> setUpSession({
    AuthUser? signedInAs = testUser,
    AuthUser user = testUser,
    String? owner,
  }) async {
    final auth = FakeAuthRepository(signedInAs: signedInAs, user: user);
    final session = TestSession(initialOwner: owner);
    final (container, _) = await createTestContainer(
      auth: auth,
      session: session,
    );
    container.listen(syncControllerProvider, (_, _) {});
    container.listen(accountSessionProvider, (_, _) {});
    return (container, auth, session);
  }

  AccountSessionStatus statusOf(ProviderContainer container) =>
      container.read(accountSessionProvider);

  group('dueño de la base local', () {
    test('el mismo usuario entra directo', () async {
      final (container, _, session) = await setUpSession(owner: testUser.id);
      expect(statusOf(container), AccountSessionStatus.ready);
      expect(session.wiper.wipes, 0);
    });

    test('sin dueño, la base pasa al usuario que entra', () async {
      final (container, _, session) = await setUpSession();
      expect(statusOf(container), AccountSessionStatus.ready);
      await pumpEventQueue();
      expect(session.store.owner, testUser.id);
    });

    test('otro usuario debe confirmar antes de abrir la base', () async {
      final (container, _, session) = await setUpSession(owner: otherUser.id);
      expect(statusOf(container), AccountSessionStatus.foreignData);

      await container
          .read(accountSessionProvider.notifier)
          .confirmForeignWipe();

      expect(session.wiper.wipes, 1);
      expect(statusOf(container), AccountSessionStatus.ready);
      await pumpEventQueue();
      expect(session.store.owner, testUser.id);
    });

    test('si no confirma, se cierra su sesión y no se borra nada', () async {
      final (container, auth, session) = await setUpSession(
        owner: otherUser.id,
      );

      await container.read(accountSessionProvider.notifier).rejectForeignData();

      expect(auth.calls, contains('signOut'));
      expect(auth.currentUser, isNull);
      expect(statusOf(container), AccountSessionStatus.signedOut);
      expect(session.wiper.wipes, 0);
      expect(session.store.owner, otherUser.id);
    });

    test('si el borrado falla, no abre los datos ajenos', () async {
      final (container, auth, session) = await setUpSession(
        owner: otherUser.id,
      );
      session.wiper.failNext = true;

      await container
          .read(accountSessionProvider.notifier)
          .confirmForeignWipe();

      expect(auth.currentUser, isNull);
      expect(statusOf(container), AccountSessionStatus.signedOut);
    });

    test('al iniciar sesión con otro usuario pide confirmar', () async {
      final (container, auth, _) = await setUpSession(
        signedInAs: null,
        user: otherUser,
        owner: testUser.id,
      );
      expect(statusOf(container), AccountSessionStatus.signedOut);

      await auth.signIn(email: otherUser.email, password: 'x');
      await pumpEventQueue();

      expect(statusOf(container), AccountSessionStatus.foreignData);
    });

    test('la sesión revocada conserva los datos y el dueño', () async {
      final (container, auth, session) = await setUpSession(owner: testUser.id);

      auth.setSession(null);
      await pumpEventQueue();
      expect(statusOf(container), AccountSessionStatus.signedOut);
      expect(session.wiper.wipes, 0);
      expect(session.store.owner, testUser.id);

      // Al volver el mismo usuario, sus datos siguen ahí.
      auth.setSession(testUser);
      await pumpEventQueue();
      expect(statusOf(container), AccountSessionStatus.ready);
    });

    test('la sesión temporal de la recuperación no abre los datos', () async {
      final (container, auth, _) = await setUpSession(
        signedInAs: null,
        owner: testUser.id,
      );
      await container.read(passwordRecoveryInProgressProvider.notifier).start();

      await auth.verifyRecoveryCode(email: testUser.email, code: '123456');
      await pumpEventQueue();

      expect(auth.currentUser, testUser);
      expect(statusOf(container), AccountSessionStatus.signedOut);
    });
  });

  group('cerrar sesión', () {
    test('sin pendientes: envía, cierra la sesión y borra lo local', () async {
      final (container, auth, session) = await setUpSession(owner: testUser.id);

      final outcome = await container.read(accountActionsProvider).signOut();

      expect(outcome, isA<SignOutDone>());
      // Lo pendiente de la demo llegó al servidor antes de borrar.
      expect(session.server.rows('movimientos'), hasLength(68));
      expect(auth.calls.last, 'signOut');
      expect(auth.currentUser, isNull);
      expect(session.wiper.wipes, 1);
      expect(session.store.owner, isNull);
      expect(statusOf(container), AccountSessionStatus.signedOut);
    });

    test('con pendientes que no se pudieron enviar pide confirmar', () async {
      final (container, auth, session) = await setUpSession(owner: testUser.id);
      session.server.offline = true;

      final outcome = await container.read(accountActionsProvider).signOut();

      expect(outcome, isA<SignOutHasPending>());
      expect((outcome as SignOutHasPending).count, 69);
      expect(auth.calls, isNot(contains('signOut')));
      expect(session.wiper.wipes, 0);
      expect(statusOf(container), AccountSessionStatus.ready);

      // Confirmado: se pierden y se borra todo.
      final forced = await container
          .read(accountActionsProvider)
          .signOut(force: true);
      expect(forced, isA<SignOutDone>());
      expect(auth.currentUser, isNull);
      expect(session.wiper.wipes, 1);
      expect(session.server.rows('movimientos'), isEmpty);
    });

    test('si el servidor rechaza un registro también avisa', () async {
      final (container, _, session) = await setUpSession(owner: testUser.id);
      final db = container.read(appDatabaseProvider);
      final rejected = (await db.select(db.movements).get()).first.id;
      session.server.rejectedIds[rejected] = '23514';

      final outcome = await container.read(accountActionsProvider).signOut();
      expect(outcome, isA<SignOutHasPending>());
      expect((outcome as SignOutHasPending).count, 1);
    });

    test('si cerrar la sesión falla, no borra nada', () async {
      final (container, auth, session) = await setUpSession(owner: testUser.id);
      auth.onCall = (method) {
        if (method == 'signOut') auth.failNext(AuthFailure.unknown);
      };

      final outcome = await container.read(accountActionsProvider).signOut();

      expect(outcome, isA<SignOutFailed>());
      expect(session.wiper.wipes, 0);
      expect(statusOf(container), AccountSessionStatus.ready);
    });

    test('completar la eliminación de la cuenta borra todo lo local', () async {
      final (container, auth, session) = await setUpSession(owner: testUser.id);
      session.server.offline = true;

      await container.read(accountActionsProvider).completeAccountDeletion();

      expect(auth.currentUser, isNull);
      expect(session.wiper.wipes, 1);
      expect(session.store.owner, isNull);
    });
  });

  group('recuperación interrumpida', () {
    test(
      'al abrir la app cierra la sesión temporal y borra la marca',
      () async {
        final store = MemoryDeviceSessionStore(recoveryInProgress: true);
        final auth = FakeAuthRepository(signedInAs: testUser);

        await clearInterruptedRecovery(store: store, auth: auth);

        expect(auth.calls, ['signOut']);
        expect(auth.currentUser, isNull);
        expect(store.recoveryInProgress, isFalse);
      },
    );

    test('sin sesión solo borra la marca', () async {
      final store = MemoryDeviceSessionStore(recoveryInProgress: true);
      final auth = FakeAuthRepository();

      await clearInterruptedRecovery(store: store, auth: auth);

      expect(auth.calls, isEmpty);
      expect(store.recoveryInProgress, isFalse);
    });

    test('sin marca no toca la sesión', () async {
      final store = MemoryDeviceSessionStore();
      final auth = FakeAuthRepository(signedInAs: testUser);

      await clearInterruptedRecovery(store: store, auth: auth);

      expect(auth.calls, isEmpty);
      expect(auth.currentUser, testUser);
    });

    test(
      'empezar y terminar la recuperación guarda y borra la marca',
      () async {
        final session = TestSession();
        final (container, _) = await createTestContainer(
          seed: false,
          session: session,
        );
        final flow = container.read(
          passwordRecoveryInProgressProvider.notifier,
        );

        await flow.start();
        expect(session.store.recoveryInProgress, isTrue);

        flow.end();
        await pumpEventQueue();
        expect(session.store.recoveryInProgress, isFalse);
      },
    );
  });
}
