import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/validators.dart';
import '../data/auth_providers.dart';
import '../domain/auth_failure.dart';
import 'countdown.dart';

/// Estado inmutable de "Verifica tu correo".
class VerifyEmailState {
  const VerifyEmailState({
    this.code = '',
    this.isSubmitting = false,
    this.isResending = false,
    this.failure,
    this.resendSeconds = 0,
    this.resent = false,
    this.verified = false,
  });

  final String code;
  final bool isSubmitting;
  final bool isResending;
  final AuthFailure? failure;

  /// Segundos que faltan para poder reenviar el código.
  final int resendSeconds;

  /// Se reenvió un código nuevo (para avisar al usuario).
  final bool resent;

  /// El correo quedó verificado y la sesión iniciada.
  final bool verified;

  bool get canSubmit => isValidOtp(code) && !isSubmitting && !verified;

  bool get canResend => resendSeconds == 0 && !isResending && !verified;

  VerifyEmailState copyWith({
    String? code,
    bool? isSubmitting,
    bool? isResending,
    AuthFailure? Function()? failure,
    int? resendSeconds,
    bool? resent,
    bool? verified,
  }) {
    return VerifyEmailState(
      code: code ?? this.code,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isResending: isResending ?? this.isResending,
      failure: failure != null ? failure() : this.failure,
      resendSeconds: resendSeconds ?? this.resendSeconds,
      resent: resent ?? this.resent,
      verified: verified ?? this.verified,
    );
  }
}

/// ViewModel de "Verifica tu correo" para el correo dado (RF-04).
final verifyEmailViewModelProvider = NotifierProvider.autoDispose
    .family<VerifyEmailViewModel, VerifyEmailState, String>(
      VerifyEmailViewModel.new,
    );

class VerifyEmailViewModel extends Notifier<VerifyEmailState> {
  VerifyEmailViewModel(this.email);

  /// Correo de la cuenta por verificar.
  final String email;

  late final Countdown _resendCountdown = Countdown(
    (remaining) => state = state.copyWith(resendSeconds: remaining),
  );

  @override
  VerifyEmailState build() {
    ref.onDispose(_resendCountdown.cancel);
    // El código se acaba de enviar: el reenvío espera desde ya.
    Future.microtask(() {
      if (ref.mounted) _resendCountdown.start(resendCooldownSeconds);
    });
    return const VerifyEmailState(resendSeconds: resendCooldownSeconds);
  }

  void setCode(String code) =>
      state = state.copyWith(code: code, failure: () => null);

  /// Verifica el código. Si es correcto, Supabase inicia la sesión y el
  /// router lleva a Inicio.
  Future<void> submit() async {
    if (!state.canSubmit) return;
    state = state.copyWith(isSubmitting: true, failure: () => null);
    try {
      await ref
          .read(authRepositoryProvider)
          .verifySignUpCode(email: email, code: state.code);
      if (!ref.mounted) return;
      state = state.copyWith(isSubmitting: false, verified: true);
    } on AuthFailureException catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(isSubmitting: false, failure: () => error.failure);
    }
  }

  Future<void> resend() async {
    if (!state.canResend) return;
    state = state.copyWith(
      isResending: true,
      resent: false,
      failure: () => null,
    );
    try {
      await ref.read(authRepositoryProvider).resendSignUpCode(email: email);
      if (!ref.mounted) return;
      state = state.copyWith(isResending: false, resent: true, code: '');
      _resendCountdown.start(resendCooldownSeconds);
    } on AuthFailureException catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(isResending: false, failure: () => error.failure);
    }
  }
}
