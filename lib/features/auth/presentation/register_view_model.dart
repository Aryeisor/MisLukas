import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/validators.dart';
import '../data/auth_providers.dart';
import '../domain/auth_failure.dart';
import 'auth_messages.dart';

/// Estado inmutable del formulario de registro.
class RegisterState {
  const RegisterState({
    this.name = '',
    this.email = '',
    this.password = '',
    this.confirmPassword = '',
    this.acceptedTerms = false,
    this.emailTouched = false,
    this.isSubmitting = false,
    this.failure,
    this.submittedEmail,
  });

  final String name;
  final String email;
  final String password;
  final String confirmPassword;
  final bool acceptedTerms;
  final bool emailTouched;
  final bool isSubmitting;

  /// Error del último envío; null si no hubo error.
  final AuthFailure? failure;

  /// Correo de la cuenta creada; cuando existe se abre "Verifica tu correo".
  final String? submittedEmail;

  PasswordRequirements get requirements => PasswordRequirements.check(password);

  PasswordStrength get strength => passwordStrength(password);

  /// El indicador de fortaleza aparece al empezar a escribir.
  bool get showStrength => password.isNotEmpty;

  String? get emailError =>
      emailTouched && email.isNotEmpty && !isValidEmail(email)
      ? 'Ingresa un correo válido'
      : null;

  /// Errores de la contraseña que no muestra la lista de requisitos.
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

  bool get canSubmit =>
      isValidName(name) &&
      isValidEmail(email) &&
      isAcceptablePassword(password) &&
      confirmPassword == password &&
      acceptedTerms &&
      !isSubmitting;

  RegisterState copyWith({
    String? name,
    String? email,
    String? password,
    String? confirmPassword,
    bool? acceptedTerms,
    bool? emailTouched,
    bool? isSubmitting,
    AuthFailure? Function()? failure,
    String? submittedEmail,
  }) {
    return RegisterState(
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      acceptedTerms: acceptedTerms ?? this.acceptedTerms,
      emailTouched: emailTouched ?? this.emailTouched,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      failure: failure != null ? failure() : this.failure,
      submittedEmail: submittedEmail ?? this.submittedEmail,
    );
  }
}

final registerViewModelProvider =
    NotifierProvider.autoDispose<RegisterViewModel, RegisterState>(
      RegisterViewModel.new,
    );

/// ViewModel del registro (RF-01 a RF-04).
class RegisterViewModel extends Notifier<RegisterState> {
  @override
  RegisterState build() => const RegisterState();

  void setName(String value) => state = state.copyWith(name: value);
  void setEmail(String value) => state = state.copyWith(email: value);
  void setPassword(String value) => state = state.copyWith(password: value);
  void setConfirmPassword(String value) =>
      state = state.copyWith(confirmPassword: value);
  void setAcceptedTerms(bool value) =>
      state = state.copyWith(acceptedTerms: value);

  void markEmailTouched() {
    if (!state.emailTouched) state = state.copyWith(emailTouched: true);
  }

  /// Crea la cuenta. Supabase envía el código de verificación al correo.
  Future<void> submit() async {
    if (!state.canSubmit) return;
    state = state.copyWith(isSubmitting: true, failure: () => null);

    final email = normalizeEmail(state.email);
    try {
      await ref
          .read(authRepositoryProvider)
          .signUp(
            name: state.name.trim(),
            email: email,
            password: state.password,
          );
      if (!ref.mounted) return;
      state = state.copyWith(isSubmitting: false, submittedEmail: email);
    } on AuthFailureException catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(isSubmitting: false, failure: () => error.failure);
    }
  }
}
