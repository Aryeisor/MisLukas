import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/validators.dart';
import '../data/auth_providers.dart';
import '../domain/auth_failure.dart';
import 'auth_messages.dart';
import 'countdown.dart';
import 'password_recovery_flow.dart';

/// Pasos de la recuperación de contraseña (docs/05 pantalla 3).
enum RecoverStep { email, code, newPassword, done }

/// Intentos fallidos permitidos con un mismo código (docs/08 §8.4).
const int maxRecoveryCodeAttempts = 5;

/// Estado inmutable de la recuperación de contraseña.
class RecoverPasswordState {
  const RecoverPasswordState({
    this.step = RecoverStep.email,
    this.email = '',
    this.emailTouched = false,
    this.code = '',
    this.failedCodeAttempts = 0,
    this.password = '',
    this.confirmPassword = '',
    this.isSubmitting = false,
    this.failure,
    this.resendSeconds = 0,
    this.codeRevision = 0,
  });

  final RecoverStep step;
  final String email;
  final bool emailTouched;
  final String code;

  /// Intentos fallidos con el código actual.
  final int failedCodeAttempts;
  final String password;
  final String confirmPassword;
  final bool isSubmitting;
  final AuthFailure? failure;

  /// Segundos que faltan para poder pedir otro código.
  final int resendSeconds;

  /// Cambia cada vez que se pide un código nuevo (para vaciar el campo).
  final int codeRevision;

  /// El código se invalidó en la app por superar los intentos.
  bool get codeLocked => failedCodeAttempts >= maxRecoveryCodeAttempts;

  String? get emailError => emailTouched && email.isNotEmpty && !isValidEmail(email)
      ? 'Ingresa un correo válido'
      : null;

  String? get codeError {
    if (codeLocked) {
      return 'Superaste los intentos con este código. Pide uno nuevo.';
    }
    final failure = this.failure;
    return failure == null ? null : authMessageFor(failure);
  }

  PasswordRequirements get requirements =>
      PasswordRequirements.check(password);

  PasswordStrength get strength => passwordStrength(password);

  String? get passwordError {
    if (password.length > passwordMaxLength) return passwordTooLongMessage;
    if (requirements.allMet && isCommonPassword(password)) {
      return commonPasswordMessage;
    }
    return null;
  }

  String? get confirmError =>
      confirmPassword.isNotEmpty && confirmPassword != password
      ? 'Las contraseñas no coinciden'
      : null;

  bool get canSendCode => isValidEmail(email) && !isSubmitting;

  bool get canVerifyCode => isValidOtp(code) && !codeLocked && !isSubmitting;

  bool get canResend => resendSeconds == 0 && !isSubmitting;

  bool get canSavePassword =>
      isAcceptablePassword(password) &&
      confirmPassword == password &&
      !isSubmitting;

  RecoverPasswordState copyWith({
    RecoverStep? step,
    String? email,
    bool? emailTouched,
    String? code,
    int? failedCodeAttempts,
    String? password,
    String? confirmPassword,
    bool? isSubmitting,
    AuthFailure? Function()? failure,
    int? resendSeconds,
    int? codeRevision,
  }) {
    return RecoverPasswordState(
      step: step ?? this.step,
      email: email ?? this.email,
      emailTouched: emailTouched ?? this.emailTouched,
      code: code ?? this.code,
      failedCodeAttempts: failedCodeAttempts ?? this.failedCodeAttempts,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      failure: failure != null ? failure() : this.failure,
      resendSeconds: resendSeconds ?? this.resendSeconds,
      codeRevision: codeRevision ?? this.codeRevision,
    );
  }
}

final recoverPasswordViewModelProvider =
    NotifierProvider.autoDispose<
      RecoverPasswordViewModel,
      RecoverPasswordState
    >(RecoverPasswordViewModel.new);

/// ViewModel de la recuperación de contraseña (RF-08 a RF-10, docs/08 §8.4).
class RecoverPasswordViewModel extends Notifier<RecoverPasswordState> {
  /// El código se verificó y la contraseña aún no se guardó.
  bool _hasRecoverySession = false;

  late final Countdown _resendCountdown = Countdown(
    (remaining) => state = state.copyWith(resendSeconds: remaining),
  );

  @override
  RecoverPasswordState build() {
    final recoveryFlow = ref.read(passwordRecoveryInProgressProvider.notifier);
    ref.onDispose(() {
      _resendCountdown.cancel();
      // Un dispose no es una salida del usuario: la sesión temporal no se
      // cierra aquí (eso lo hace [cancel]). Solo se libera el router, después
      // del dispose, porque no se puede cambiar otro provider durante él.
      Future.microtask(recoveryFlow.end);
    });
    return const RecoverPasswordState();
  }

  PasswordRecoveryInProgress get _recoveryFlow =>
      ref.read(passwordRecoveryInProgressProvider.notifier);

  // Paso 1: correo

  void setEmail(String value) =>
      state = state.copyWith(email: value, failure: () => null);

  void markEmailTouched() {
    if (!state.emailTouched) state = state.copyWith(emailTouched: true);
  }

  /// Pide el código. La respuesta es la misma exista o no la cuenta (RF-09):
  /// solo se detiene si no hay conexión o hay demasiados intentos.
  Future<void> sendCode() async {
    if (!state.canSendCode) return;
    if (await _requestCode()) {
      state = state.copyWith(step: RecoverStep.code);
    }
  }

  // Paso 2: código

  void setCode(String value) =>
      state = state.copyWith(code: value, failure: () => null);

  Future<void> verifyCode() async {
    if (!state.canVerifyCode) return;
    state = state.copyWith(isSubmitting: true, failure: () => null);
    // Antes de verificar: la sesión temporal llega durante la llamada y el
    // router debe dejar al usuario en esta pantalla.
    _recoveryFlow.start();
    try {
      await ref
          .read(authRepositoryProvider)
          .verifyRecoveryCode(email: state.email, code: state.code);
      _hasRecoverySession = true;
      if (!ref.mounted) return;
      state = state.copyWith(isSubmitting: false, step: RecoverStep.newPassword);
    } on AuthFailureException catch (error) {
      if (!ref.mounted) return;
      _recoveryFlow.end();
      final wrongCode = error.failure == AuthFailure.invalidCode;
      state = state.copyWith(
        isSubmitting: false,
        failure: () => error.failure,
        failedCodeAttempts: wrongCode
            ? state.failedCodeAttempts + 1
            : state.failedCodeAttempts,
      );
    }
  }

  /// Pide un código nuevo; el anterior deja de servir.
  Future<void> resendCode() async {
    if (!state.canResend) return;
    await _requestCode();
  }

  // Paso 3: contraseña nueva

  void setPassword(String value) =>
      state = state.copyWith(password: value, failure: () => null);

  void setConfirmPassword(String value) =>
      state = state.copyWith(confirmPassword: value);

  /// Guarda la contraseña y cierra la sesión en todos los dispositivos (RF-10).
  Future<void> savePassword() async {
    if (!state.canSavePassword) return;
    state = state.copyWith(isSubmitting: true, failure: () => null);
    try {
      await ref
          .read(authRepositoryProvider)
          .updatePassword(newPassword: state.password);
      _hasRecoverySession = false;
      if (!ref.mounted) return;
      state = state.copyWith(isSubmitting: false, step: RecoverStep.done);
      _recoveryFlow.end();
    } on AuthFailureException catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(isSubmitting: false, failure: () => error.failure);
    }
  }

  /// El usuario sale de la recuperación (Volver o atrás del sistema). Si ya
  /// verificó el código y no guardó la contraseña, cierra la sesión temporal.
  Future<void> cancel() async {
    if (_hasRecoverySession) {
      _hasRecoverySession = false;
      try {
        await ref.read(authRepositoryProvider).signOut();
      } on AuthFailureException {
        // signOut solo falla por causas distintas a la red; la sesión local
        // ya se borró antes de avisar al servidor.
      }
    }
    if (ref.mounted) _recoveryFlow.end();
  }

  /// Envía el código. Devuelve true si se debe continuar al paso del código.
  Future<bool> _requestCode() async {
    state = state.copyWith(isSubmitting: true, failure: () => null);
    AuthFailure? failure;
    try {
      await ref
          .read(authRepositoryProvider)
          .sendPasswordRecovery(email: state.email);
    } on AuthFailureException catch (error) {
      failure = error.failure;
    }
    if (!ref.mounted) return false;

    if (failure == AuthFailure.network || failure == AuthFailure.rateLimited) {
      state = state.copyWith(isSubmitting: false, failure: () => failure);
      return false;
    }
    // Cualquier otro resultado se muestra igual que el éxito.
    state = state.copyWith(
      isSubmitting: false,
      code: '',
      failedCodeAttempts: 0,
      codeRevision: state.codeRevision + 1,
    );
    _resendCountdown.start(resendCooldownSeconds);
    return true;
  }
}
