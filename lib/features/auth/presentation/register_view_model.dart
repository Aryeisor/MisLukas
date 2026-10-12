import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/validators.dart';

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
    this.submittedEmail,
  });

  final String name;
  final String email;
  final String password;
  final String confirmPassword;
  final bool acceptedTerms;
  final bool emailTouched;
  final bool isSubmitting;

  /// Correo de la cuenta creada; cuando existe se muestra "Verifica tu correo".
  final String? submittedEmail;

  PasswordRequirements get requirements =>
      PasswordRequirements.check(password);

  PasswordStrength get strength => passwordStrength(password);

  /// El indicador de fortaleza aparece al empezar a escribir.
  bool get showStrength => password.isNotEmpty;

  String? get emailError => emailTouched && email.isNotEmpty && !isValidEmail(email)
      ? 'Ingresa un correo válido'
      : null;

  String? get confirmError =>
      confirmPassword.isNotEmpty && confirmPassword != password
      ? 'Las contraseñas no coinciden'
      : null;

  bool get canSubmit =>
      name.trim().isNotEmpty &&
      isValidEmail(email) &&
      requirements.allMet &&
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
      submittedEmail: submittedEmail ?? this.submittedEmail,
    );
  }
}

/// Duración simulada de la creación de la cuenta.
const Duration registerDemoDelay = Duration(seconds: 1);

final registerViewModelProvider =
    NotifierProvider.autoDispose<RegisterViewModel, RegisterState>(
      RegisterViewModel.new,
    );

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

  /// SOLO DEMO: simula la creación de la cuenta (Supabase Auth en la Fase 5).
  Future<void> submit() async {
    if (!state.canSubmit) return;
    state = state.copyWith(isSubmitting: true);

    await Future<void>.delayed(registerDemoDelay);
    if (!ref.mounted) return;

    state = state.copyWith(
      isSubmitting: false,
      submittedEmail: state.email.trim(),
    );
  }
}
