import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/validators.dart';

/// Estado del envío del formulario de inicio de sesión.
enum LoginStatus { idle, submitting, invalidCredentials, locked, success }

/// Estado inmutable del formulario de inicio de sesión.
class LoginState {
  const LoginState({
    this.email = '',
    this.password = '',
    this.emailTouched = false,
    this.status = LoginStatus.idle,
  });

  final String email;
  final String password;

  /// El usuario ya salió del campo de correo: se pueden mostrar sus errores.
  final bool emailTouched;
  final LoginStatus status;

  bool get isSubmitting => status == LoginStatus.submitting;

  String? get emailError => emailTouched && email.isNotEmpty && !isValidEmail(email)
      ? 'Ingresa un correo válido'
      : null;

  bool get canSubmit =>
      isValidEmail(email) &&
      password.isNotEmpty &&
      status != LoginStatus.submitting &&
      status != LoginStatus.locked;

  LoginState copyWith({
    String? email,
    String? password,
    bool? emailTouched,
    LoginStatus? status,
  }) {
    return LoginState(
      email: email ?? this.email,
      password: password ?? this.password,
      emailTouched: emailTouched ?? this.emailTouched,
      status: status ?? this.status,
    );
  }
}

/// Duración simulada de la petición de inicio de sesión.
const Duration loginDemoDelay = Duration(seconds: 1);

final loginViewModelProvider =
    NotifierProvider.autoDispose<LoginViewModel, LoginState>(
      LoginViewModel.new,
    );

class LoginViewModel extends Notifier<LoginState> {
  // SOLO DEMO (Fase 3). Simula las respuestas del servidor hasta la Fase 5:
  // - error@demo.com    -> credenciales incorrectas (mensaje genérico, RF-06).
  // - bloqueado@demo.com -> bloqueo temporal por intentos fallidos (RF-07).
  // - cualquier otro correo válido -> inicio de sesión correcto.
  static const String _demoInvalidEmail = 'error@demo.com';
  static const String _demoLockedEmail = 'bloqueado@demo.com';

  @override
  LoginState build() => const LoginState();

  void setEmail(String email) {
    // Cambiar el correo limpia el error o el bloqueo del intento anterior.
    state = state.copyWith(email: email, status: LoginStatus.idle);
  }

  void setPassword(String password) {
    final status = state.status == LoginStatus.invalidCredentials
        ? LoginStatus.idle
        : state.status;
    state = state.copyWith(password: password, status: status);
  }

  void markEmailTouched() {
    if (!state.emailTouched) state = state.copyWith(emailTouched: true);
  }

  Future<void> submit() async {
    if (!state.canSubmit) return;
    state = state.copyWith(status: LoginStatus.submitting);

    await Future<void>.delayed(loginDemoDelay);
    if (!ref.mounted) return;

    final email = state.email.trim().toLowerCase();
    final status = switch (email) {
      _demoInvalidEmail => LoginStatus.invalidCredentials,
      _demoLockedEmail => LoginStatus.locked,
      _ => LoginStatus.success,
    };
    state = state.copyWith(status: status);
  }
}
