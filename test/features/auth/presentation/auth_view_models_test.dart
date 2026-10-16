import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/features/auth/data/auth_providers.dart';
import 'package:mislukas/features/auth/domain/auth_failure.dart';
import 'package:mislukas/features/auth/presentation/auth_messages.dart';
import 'package:mislukas/features/auth/presentation/countdown.dart';
import 'package:mislukas/features/auth/presentation/login_view_model.dart';
import 'package:mislukas/features/auth/presentation/password_recovery_flow.dart';
import 'package:mislukas/features/auth/presentation/recover_password_view_model.dart';
import 'package:mislukas/features/auth/presentation/register_view_model.dart';
import 'package:mislukas/features/auth/presentation/verify_email_view_model.dart';

import '../../../helpers/fake_auth_repository.dart';

void main() {
  const email = 'camila@ejemplo.com';
  const goodPassword = 'Lukas#Ahorro26';

  late FakeAuthRepository auth;
  late ProviderContainer container;

  setUp(() {
    auth = FakeAuthRepository();
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
    );
    addTearDown(container.dispose);
  });

  group('LoginViewModel', () {
    LoginViewModel login() {
      // Mantiene vivo el provider autoDispose durante la prueba.
      container.listen(loginViewModelProvider, (_, _) {});
      return container.read(loginViewModelProvider.notifier)
        ..setEmail(email)
        ..setPassword('Cualquiera1*');
    }

    LoginState state() => container.read(loginViewModelProvider);

    test('esperas crecientes: 1, 2, 4, 8, 16 y máximo 30 s', () {
      expect(
        [for (var i = 0; i <= 7; i++) loginRetryDelaySeconds(i)],
        [0, 1, 2, 4, 8, 16, 30, 30],
      );
    });

    test('inicio de sesión correcto deja la sesión iniciada', () async {
      await login().submit();
      expect(auth.calls, ['signIn']);
      expect(auth.currentUser, testUser);
      expect(state().failure, isNull);
      expect(state().isSubmitting, isFalse);
    });

    test('credenciales incorrectas: error genérico y espera', () async {
      auth.failNext(AuthFailure.invalidCredentials);
      await login().submit();

      expect(state().failure, AuthFailure.invalidCredentials);
      expect(authMessageFor(state().failure!), invalidCredentialsMessage);
      expect(state().retrySeconds, 1);
      expect(state().canSubmit, isFalse);
    });

    test('sin conexión no agrega espera', () async {
      auth.failNext(AuthFailure.network);
      await login().submit();

      expect(state().failure, AuthFailure.network);
      expect(state().retrySeconds, 0);
      expect(state().canSubmit, isTrue);
    });

    test('editar el correo limpia el error', () async {
      auth.failNext(AuthFailure.network);
      final viewModel = login();
      await viewModel.submit();
      viewModel.setEmail('otro@ejemplo.com');
      expect(state().failure, isNull);
    });
  });

  group('RegisterViewModel', () {
    RegisterViewModel register({String password = goodPassword}) {
      container.listen(registerViewModelProvider, (_, _) {});
      return container.read(registerViewModelProvider.notifier)
        ..setName('Camila')
        ..setEmail('  Camila@Ejemplo.com ')
        ..setPassword(password)
        ..setConfirmPassword(password)
        ..setAcceptedTerms(true);
    }

    RegisterState state() => container.read(registerViewModelProvider);

    test('crea la cuenta y guarda el correo normalizado', () async {
      await register().submit();
      expect(auth.calls, ['signUp']);
      expect(state().submittedEmail, email);
    });

    test('no envía contraseñas comunes, largas o un nombre vacío', () async {
      register(password: 'Password1!');
      expect(state().passwordError, commonPasswordMessage);
      expect(state().canSubmit, isFalse);

      final long = 'Aa1*${'x' * 69}';
      register(password: long);
      expect(state().passwordError, passwordTooLongMessage);
      expect(state().canSubmit, isFalse);

      register().setName('   ');
      expect(state().canSubmit, isFalse);

      await container.read(registerViewModelProvider.notifier).submit();
      expect(auth.calls, isEmpty);
    });

    test('un error del servidor queda en el estado', () async {
      auth.failNext(AuthFailure.weakPassword);
      await register().submit();
      expect(state().failure, AuthFailure.weakPassword);
      expect(state().submittedEmail, isNull);
    });
  });

  group('VerifyEmailViewModel', () {
    VerifyEmailViewModel verify() {
      container.listen(verifyEmailViewModelProvider(email), (_, _) {});
      return container.read(verifyEmailViewModelProvider(email).notifier);
    }

    VerifyEmailState state() =>
        container.read(verifyEmailViewModelProvider(email));

    test('el reenvío espera 60 s desde el inicio', () {
      verify();
      expect(state().resendSeconds, resendCooldownSeconds);
      expect(state().canResend, isFalse);
    });

    test('solo verifica con 6 dígitos y al acertar inicia sesión', () async {
      final viewModel = verify()..setCode('12345');
      expect(state().canSubmit, isFalse);

      viewModel.setCode('123456');
      await viewModel.submit();
      expect(auth.calls, ['verifySignUpCode']);
      expect(state().verified, isTrue);
      expect(auth.currentUser, testUser);
    });

    test('código incorrecto muestra el error', () async {
      auth.failNext(AuthFailure.invalidCode);
      final viewModel = verify()..setCode('000000');
      await viewModel.submit();
      expect(state().failure, AuthFailure.invalidCode);
      expect(state().verified, isFalse);
    });
  });

  group('RecoverPasswordViewModel', () {
    RecoverPasswordViewModel recover() {
      container.listen(recoverPasswordViewModelProvider, (_, _) {});
      return container.read(recoverPasswordViewModelProvider.notifier);
    }

    RecoverPasswordState state() =>
        container.read(recoverPasswordViewModelProvider);

    test('avanza al código con el mismo mensaje exista o no la cuenta', () async {
      for (final failure in [null, AuthFailure.invalidCredentials, AuthFailure.unknown]) {
        container.invalidate(recoverPasswordViewModelProvider);
        if (failure != null) auth.failNext(failure);
        final viewModel = recover()..setEmail(email);
        await viewModel.sendCode();

        expect(state().step, RecoverStep.code, reason: '$failure');
        expect(state().failure, isNull, reason: '$failure');
        expect(state().resendSeconds, resendCooldownSeconds);
      }
    });

    test('sin conexión o con demasiados intentos se queda en el correo', () async {
      for (final failure in [AuthFailure.network, AuthFailure.rateLimited]) {
        container.invalidate(recoverPasswordViewModelProvider);
        auth.failNext(failure);
        final viewModel = recover()..setEmail(email);
        await viewModel.sendCode();

        expect(state().step, RecoverStep.email);
        expect(state().failure, failure);
      }
    });

    test('después de 5 códigos incorrectos hay que pedir uno nuevo', () async {
      final viewModel = recover()..setEmail(email);
      await viewModel.sendCode();

      for (var i = 0; i < maxRecoveryCodeAttempts; i++) {
        auth.failNext(AuthFailure.invalidCode);
        viewModel.setCode('000000');
        await viewModel.verifyCode();
      }
      expect(state().codeLocked, isTrue);
      expect(state().canVerifyCode, isFalse);
      expect(state().codeError, contains('Pide uno nuevo'));

      // Otro intento no llega al servidor.
      auth.calls.clear();
      await viewModel.verifyCode();
      expect(auth.calls, isEmpty);
    });

    test('flujo completo: código, contraseña nueva y cierre global', () async {
      final viewModel = recover()..setEmail(email);
      await viewModel.sendCode();
      viewModel.setCode('123456');
      await viewModel.verifyCode();
      expect(state().step, RecoverStep.newPassword);
      expect(auth.currentUser, testUser);

      viewModel
        ..setPassword(goodPassword)
        ..setConfirmPassword(goodPassword);
      await viewModel.savePassword();

      expect(state().step, RecoverStep.done);
      expect(auth.calls, [
        'sendPasswordRecovery',
        'verifyRecoveryCode',
        'updatePassword',
      ]);
      expect(auth.currentUser, isNull);
    });

    bool recoveryInProgress() =>
        container.read(passwordRecoveryInProgressProvider);

    Future<RecoverPasswordViewModel> verified() async {
      final viewModel = recover()..setEmail(email);
      await viewModel.sendCode();
      viewModel.setCode('123456');
      await viewModel.verifyCode();
      return viewModel;
    }

    test('la recuperación queda en curso antes de que llegue la sesión', () async {
      final viewModel = recover()..setEmail(email);
      await viewModel.sendCode();
      viewModel.setCode('123456');

      // La sesión temporal se emite durante verifyRecoveryCode: al llamarlo,
      // el router ya debe ver la recuperación en curso.
      bool? inProgressWhenVerifying;
      auth.onCall = (method) {
        if (method == 'verifyRecoveryCode') {
          inProgressWhenVerifying = recoveryInProgress();
        }
      };

      await viewModel.verifyCode();
      expect(inProgressWhenVerifying, isTrue);
      expect(recoveryInProgress(), isTrue);
    });

    test('un código incorrecto termina la recuperación en curso', () async {
      final viewModel = recover()..setEmail(email);
      await viewModel.sendCode();
      auth.failNext(AuthFailure.invalidCode);
      viewModel.setCode('000000');
      await viewModel.verifyCode();
      expect(recoveryInProgress(), isFalse);
    });

    test('un dispose no cierra la sesión temporal', () async {
      await verified();
      expect(auth.currentUser, testUser);

      container.invalidate(recoverPasswordViewModelProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(auth.calls, isNot(contains('signOut')));
      expect(auth.currentUser, testUser);
    });

    test('cancelar después de verificar cierra la sesión temporal', () async {
      final viewModel = await verified();
      await viewModel.cancel();

      expect(auth.calls.last, 'signOut');
      expect(auth.currentUser, isNull);
      expect(recoveryInProgress(), isFalse);
    });

    test('cancelar antes de verificar no llama al servidor', () async {
      final viewModel = recover()..setEmail(email);
      await viewModel.sendCode();
      await viewModel.cancel();
      expect(auth.calls, ['sendPasswordRecovery']);
    });

    test('guardar la contraseña termina la recuperación en curso', () async {
      final viewModel = await verified();
      viewModel
        ..setPassword(goodPassword)
        ..setConfirmPassword(goodPassword);
      await viewModel.savePassword();
      expect(recoveryInProgress(), isFalse);
    });

    test('la contraseña igual a la anterior muestra el error', () async {
      final viewModel = recover()..setEmail(email);
      await viewModel.sendCode();
      viewModel.setCode('123456');
      await viewModel.verifyCode();

      auth.failNext(AuthFailure.samePassword);
      viewModel
        ..setPassword(goodPassword)
        ..setConfirmPassword(goodPassword);
      await viewModel.savePassword();

      expect(state().step, RecoverStep.newPassword);
      expect(state().failure, AuthFailure.samePassword);
    });
  });
}
