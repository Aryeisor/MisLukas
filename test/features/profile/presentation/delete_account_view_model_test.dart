import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/sync/sync_controller.dart';
import 'package:mislukas/features/auth/domain/auth_failure.dart';
import 'package:mislukas/features/auth/presentation/account_session_controller.dart';
import 'package:mislukas/features/profile/data/profile_providers.dart';
import 'package:mislukas/features/profile/domain/repositories/account_repository.dart';
import 'package:mislukas/features/profile/presentation/delete_account_view_model.dart';

import '../../../helpers/fake_account_repository.dart';
import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/fake_sync_server.dart';
import '../../../helpers/test_container.dart';
import '../../../helpers/test_session.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeAccountRepository account;
  late TestSession session;
  late MutableClock clock;
  late ProviderContainer container;

  setUp(() async {
    auth = FakeAuthRepository(signedInAs: testUser);
    account = FakeAccountRepository();
    session = TestSession(initialOwner: testUser.id);
    clock = MutableClock(DateTime(2026, 9, 22, 10, 30));
    (container, _) = await createTestContainer(
      auth: auth,
      session: session,
      clock: clock,
      overrides: [accountRepositoryProvider.overrideWithValue(account)],
    );
    container.listen(syncControllerProvider, (_, _) {});
    container.listen(accountSessionProvider, (_, _) {});
    container.listen(deleteAccountViewModelProvider, (_, _) {});
  });

  DeleteAccountState state() => container.read(deleteAccountViewModelProvider);
  DeleteAccountViewModel viewModel() =>
      container.read(deleteAccountViewModelProvider.notifier);

  test(
    'con la contraseña correcta borra archivos, cuenta y datos locales',
    () async {
      viewModel().setPassword('Clave123*');
      await viewModel().submit();

      expect(auth.calls, contains('reauthenticate'));
      expect(account.calls, ['deleteStoredFiles', 'deleteAccount']);
      expect(state().step, DeleteAccountStep.done);
      expect(auth.currentUser, isNull);
      expect(session.wiper.wipes, 1);
      expect(session.store.owner, isNull);
      expect(
        container.read(accountSessionProvider),
        AccountSessionStatus.signedOut,
      );
    },
  );

  test('con la contraseña incorrecta no borra nada', () async {
    auth.failNext(AuthFailure.invalidCredentials);
    viewModel().setPassword('mala');
    await viewModel().submit();

    expect(state().step, DeleteAccountStep.password);
    expect(state().error, DeleteAccountError.wrongPassword);
    expect(state().errorMessage, 'La contraseña no es correcta.');
    expect(account.calls, isEmpty);
    expect(session.wiper.wipes, 0);
  });

  test('sin conexión al verificar la contraseña lo dice', () async {
    auth.failNext(AuthFailure.network);
    viewModel().setPassword('Clave123*');
    await viewModel().submit();
    expect(state().error, DeleteAccountError.network);
    expect(account.calls, isEmpty);
  });

  test('si eliminar_mi_cuenta falla después de borrar los archivos, se '
      'reintenta sin pedir otra vez la contraseña', () async {
    account.deleteFailures.add(AccountDeletionFailure.network);
    viewModel().setPassword('Clave123*');
    await viewModel().submit();

    expect(account.calls, ['deleteStoredFiles', 'deleteAccount']);
    expect(state().step, DeleteAccountStep.retry);
    expect(state().error, DeleteAccountError.interrupted);
    expect(
      state().errorMessage,
      'No pudimos terminar de eliminar tu cuenta. Revisa tu conexión e '
      'intenta de nuevo.',
    );
    // La contraseña no se conserva.
    expect(state().password, isEmpty);
    expect(state().canSubmit, isTrue);
    expect(session.wiper.wipes, 0);
    expect(auth.currentUser, testUser);

    clock.advance(const Duration(minutes: 2));
    await viewModel().submit();

    expect(
      auth.calls.where((c) => c == 'reauthenticate'),
      hasLength(1),
      reason: 'el reintento no vuelve a verificar la contraseña',
    );
    expect(account.calls, [
      'deleteStoredFiles',
      'deleteAccount',
      'deleteStoredFiles',
      'deleteAccount',
    ]);
    expect(state().step, DeleteAccountStep.done);
    expect(session.wiper.wipes, 1);
  });

  test(
    'pasado el tiempo de la verificación pide la contraseña otra vez',
    () async {
      account.deleteFailures.add(AccountDeletionFailure.network);
      viewModel().setPassword('Clave123*');
      await viewModel().submit();
      expect(state().step, DeleteAccountStep.retry);

      clock.advance(const Duration(minutes: 5));
      await viewModel().submit();

      expect(state().step, DeleteAccountStep.password);
      expect(state().error, DeleteAccountError.reauthenticate);
      expect(account.calls, hasLength(2), reason: 'no se reintentó');

      viewModel().setPassword('Clave123*');
      await viewModel().submit();
      expect(auth.calls.where((c) => c == 'reauthenticate'), hasLength(2));
      expect(state().step, DeleteAccountStep.done);
    },
  );

  test('si el servidor exige verificar de nuevo, pide la contraseña', () async {
    account.deleteFailures.add(AccountDeletionFailure.reauthenticationRequired);
    viewModel().setPassword('Clave123*');
    await viewModel().submit();

    expect(state().step, DeleteAccountStep.password);
    expect(state().error, DeleteAccountError.reauthenticate);

    // Aunque no hayan pasado 5 minutos, el reintento verifica la contraseña.
    viewModel().setPassword('Clave123*');
    await viewModel().submit();
    expect(auth.calls.where((c) => c == 'reauthenticate'), hasLength(2));
    expect(state().step, DeleteAccountStep.done);
  });

  test('sin contraseña no se puede enviar', () async {
    expect(state().canSubmit, isFalse);
    await viewModel().submit();
    expect(auth.calls, isEmpty);
  });
}
