import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/validators.dart';
import '../data/auth_providers.dart';
import '../domain/auth_failure.dart';

/// Estado inmutable del formulario de inicio de sesión.
class LoginState {
  const LoginState({
    this.email = '',
    this.password = '',
    this.emailTouched = false,
    this.isSubmitting = false,
    this.failure,
    this.retrySeconds = 0,
  });

  final String email;
  final String password;

  /// El usuario ya salió del campo de correo: se pueden mostrar sus errores.
  final bool emailTouched;
  final bool isSubmitting;

  /// Error del último intento; null si no hubo error.
  final AuthFailure? failure;

  /// Segundos de espera antes de poder intentar de nuevo; 0 si no hay espera.
  final int retrySeconds;

  String? get emailError => emailTouched && email.isNotEmpty && !isValidEmail(email)
      ? 'Ingresa un correo válido'
      : null;

  bool get canSubmit =>
      isValidEmail(email) &&
      password.isNotEmpty &&
      !isSubmitting &&
      retrySeconds == 0;

  LoginState copyWith({
    String? email,
    String? password,
    bool? emailTouched,
    bool? isSubmitting,
    AuthFailure? Function()? failure,
    int? retrySeconds,
  }) {
    return LoginState(
      email: email ?? this.email,
      password: password ?? this.password,
      emailTouched: emailTouched ?? this.emailTouched,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      failure: failure != null ? failure() : this.failure,
      retrySeconds: retrySeconds ?? this.retrySeconds,
    );
  }
}

/// Espera máxima entre intentos fallidos.
const int loginMaxRetrySeconds = 30;

/// Espera después de [failedAttempts] intentos fallidos: 1, 2, 4, 8, 16 y 30 s.
int loginRetryDelaySeconds(int failedAttempts) {
  if (failedAttempts <= 0) return 0;
  return min(1 << (failedAttempts - 1).clamp(0, 5), loginMaxRetrySeconds);
}

final loginViewModelProvider =
    NotifierProvider.autoDispose<LoginViewModel, LoginState>(
      LoginViewModel.new,
    );

/// ViewModel del inicio de sesión (RF-05 a RF-07).
///
/// No hay estado de éxito: al iniciar la sesión, el redirect del router lleva
/// a Inicio. Después de cada fallo de credenciales o de bloqueo, el botón se
/// deshabilita con esperas crecientes (docs/08 §8.2.1). Es un apoyo de
/// experiencia, no una medida de seguridad: los límites reales están en el
/// servidor.
class LoginViewModel extends Notifier<LoginState> {
  int _failedAttempts = 0;
  Timer? _retryTimer;

  @override
  LoginState build() {
    ref.onDispose(() => _retryTimer?.cancel());
    return const LoginState();
  }

  void setEmail(String email) {
    // Cambiar el correo limpia el error del intento anterior.
    state = state.copyWith(email: email, failure: () => null);
  }

  void setPassword(String password) {
    state = state.copyWith(password: password, failure: () => null);
  }

  void markEmailTouched() {
    if (!state.emailTouched) state = state.copyWith(emailTouched: true);
  }

  Future<void> submit() async {
    if (!state.canSubmit) return;
    state = state.copyWith(isSubmitting: true, failure: () => null);

    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(email: state.email, password: state.password);
      if (!ref.mounted) return;
      _failedAttempts = 0;
      state = state.copyWith(isSubmitting: false);
    } on AuthFailureException catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(isSubmitting: false, failure: () => error.failure);
      if (error.failure == AuthFailure.invalidCredentials ||
          error.failure == AuthFailure.rateLimited) {
        _failedAttempts++;
        _startRetryCountdown(loginRetryDelaySeconds(_failedAttempts));
      }
    }
  }

  void _startRetryCountdown(int seconds) {
    _retryTimer?.cancel();
    state = state.copyWith(retrySeconds: seconds);
    _retryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = state.retrySeconds - 1;
      state = state.copyWith(retrySeconds: max(remaining, 0));
      if (remaining <= 0) timer.cancel();
    });
  }
}
