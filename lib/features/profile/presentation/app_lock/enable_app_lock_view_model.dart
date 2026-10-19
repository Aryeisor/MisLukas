import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/security/device_authenticator.dart';
import '../../../auth/data/auth_providers.dart';
import '../../../auth/domain/auth_failure.dart';
import '../../../auth/presentation/app_lock/app_lock_controller.dart';

/// Paso de la activación del bloqueo desde el Perfil.
enum EnableAppLockStep {
  /// Escribir la contraseña de la cuenta.
  password,

  /// La contraseña se verificó: falta confirmar con el bloqueo del celular.
  confirmDevice,

  /// El bloqueo quedó activo.
  done,
}

/// Error mostrado al usuario.
enum EnableAppLockError {
  wrongPassword('La contraseña no es correcta.'),
  network('Necesitas conexión a internet para verificar tu contraseña.'),
  rateLimited('Demasiados intentos. Espera unos minutos e intenta de nuevo.'),
  unknown('No pudimos verificar tu contraseña. Intenta de nuevo más tarde.'),
  canceled(
    'No se activó. Toca Activar para intentarlo de nuevo.',
  ),
  lockedOut(
    'Tu celular pausó el desbloqueo por varios intentos fallidos. Espera un '
    'momento e inténtalo de nuevo.',
  ),
  noDeviceLock(
    'Configura un bloqueo de pantalla en tu celular para proteger MisLukas.',
  ),
  deviceFailed('No pudimos usar el bloqueo de tu celular. Inténtalo de nuevo.');

  const EnableAppLockError(this.message);

  final String message;
}

/// Estado inmutable de la activación del bloqueo.
class EnableAppLockState {
  const EnableAppLockState({
    this.step = EnableAppLockStep.password,
    this.password = '',
    this.isSubmitting = false,
    this.error,
  });

  final EnableAppLockStep step;
  final String password;
  final bool isSubmitting;
  final EnableAppLockError? error;

  bool get canSubmit =>
      !isSubmitting &&
      (step == EnableAppLockStep.confirmDevice ||
          (step == EnableAppLockStep.password && password.isNotEmpty));

  EnableAppLockState copyWith({
    EnableAppLockStep? step,
    String? password,
    bool? isSubmitting,
    EnableAppLockError? Function()? error,
  }) {
    return EnableAppLockState(
      step: step ?? this.step,
      password: password ?? this.password,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error != null ? error() : this.error,
    );
  }
}

final enableAppLockViewModelProvider =
    NotifierProvider.autoDispose<EnableAppLockViewModel, EnableAppLockState>(
      EnableAppLockViewModel.new,
    );

/// Activa el bloqueo desde el Perfil (RF-46, docs/07 §7.7). Primero verifica
/// la contraseña de la cuenta con el servidor, porque quien tome el celular
/// desbloqueado con la app abierta no la conoce; luego confirma con el
/// diálogo del sistema. La contraseña no se conserva.
class EnableAppLockViewModel extends Notifier<EnableAppLockState> {
  @override
  EnableAppLockState build() => const EnableAppLockState();

  void setPassword(String value) =>
      state = state.copyWith(password: value, error: () => null);

  Future<void> submit() async {
    if (!state.canSubmit) return;
    state = state.copyWith(isSubmitting: true, error: () => null);

    if (state.step == EnableAppLockStep.password) {
      try {
        await ref
            .read(authRepositoryProvider)
            .reauthenticate(password: state.password);
      } on AuthFailureException catch (error) {
        if (!ref.mounted) return;
        state = state.copyWith(
          isSubmitting: false,
          error: () => switch (error.failure) {
            AuthFailure.invalidCredentials => EnableAppLockError.wrongPassword,
            AuthFailure.network => EnableAppLockError.network,
            AuthFailure.rateLimited => EnableAppLockError.rateLimited,
            _ => EnableAppLockError.unknown,
          },
        );
        return;
      }
      if (!ref.mounted) return;
      // La contraseña ya no hace falta: no se conserva en el estado.
      state = state.copyWith(
        step: EnableAppLockStep.confirmDevice,
        password: '',
      );
    }

    final result = await ref.read(appLockProvider.notifier).enable();
    if (!ref.mounted) return;
    state = state.copyWith(
      isSubmitting: false,
      step: result == DeviceAuthResult.success ? EnableAppLockStep.done : null,
      error: () => switch (result) {
        DeviceAuthResult.success => null,
        DeviceAuthResult.canceled ||
        DeviceAuthResult.interrupted => EnableAppLockError.canceled,
        DeviceAuthResult.lockedOut => EnableAppLockError.lockedOut,
        DeviceAuthResult.noDeviceLock => EnableAppLockError.noDeviceLock,
        DeviceAuthResult.failed => EnableAppLockError.deviceFailed,
      },
    );
  }
}
