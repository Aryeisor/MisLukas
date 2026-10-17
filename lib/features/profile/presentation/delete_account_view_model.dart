import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/utils_providers.dart';
import '../../auth/data/auth_providers.dart';
import '../../auth/domain/auth_failure.dart';
import '../../auth/presentation/account_session_controller.dart';
import '../data/profile_providers.dart';
import '../domain/repositories/account_repository.dart';

/// Paso de la eliminación de la cuenta.
enum DeleteAccountStep {
  /// Escribir la contraseña.
  password,

  /// Se verificó la contraseña pero la eliminación falló: se puede reintentar
  /// sin escribirla de nuevo.
  retry,

  /// La cuenta se eliminó.
  done,
}

/// Error mostrado al usuario.
enum DeleteAccountError {
  wrongPassword,
  network,
  rateLimited,

  /// Pasó demasiado tiempo desde que se verificó la contraseña.
  reauthenticate,

  /// La eliminación se interrumpió después de borrar los archivos.
  interrupted,
  unknown,
}

/// Estado inmutable de la eliminación de la cuenta.
class DeleteAccountState {
  const DeleteAccountState({
    this.step = DeleteAccountStep.password,
    this.password = '',
    this.isSubmitting = false,
    this.error,
  });

  final DeleteAccountStep step;
  final String password;
  final bool isSubmitting;
  final DeleteAccountError? error;

  bool get canSubmit =>
      !isSubmitting &&
      (step == DeleteAccountStep.retry ||
          (step == DeleteAccountStep.password && password.isNotEmpty));

  String? get errorMessage => switch (error) {
    null => null,
    DeleteAccountError.wrongPassword => 'La contraseña no es correcta.',
    DeleteAccountError.network =>
      'Necesitas conexión a internet para eliminar tu cuenta.',
    DeleteAccountError.rateLimited =>
      'Demasiados intentos. Espera unos minutos e intenta de nuevo.',
    DeleteAccountError.reauthenticate =>
      'Por seguridad, vuelve a escribir tu contraseña.',
    DeleteAccountError.interrupted =>
      'No pudimos terminar de eliminar tu cuenta. Revisa tu conexión e '
          'intenta de nuevo.',
    DeleteAccountError.unknown =>
      'No pudimos eliminar tu cuenta. Intenta de nuevo más tarde.',
  };

  DeleteAccountState copyWith({
    DeleteAccountStep? step,
    String? password,
    bool? isSubmitting,
    DeleteAccountError? Function()? error,
  }) {
    return DeleteAccountState(
      step: step ?? this.step,
      password: password ?? this.password,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error != null ? error() : this.error,
    );
  }
}

final deleteAccountViewModelProvider =
    NotifierProvider.autoDispose<DeleteAccountViewModel, DeleteAccountState>(
      DeleteAccountViewModel.new,
    );

/// ViewModel de la eliminación de la cuenta (RF-48, docs/08 §8.9.4):
/// verifica la contraseña, borra los archivos del usuario en Storage, elimina
/// la cuenta en el servidor y borra todo lo local.
///
/// Si la eliminación falla después de verificar la contraseña, se puede
/// reintentar sin escribirla otra vez mientras no pase [reauthenticationWindow]
/// (el servidor acepta 5 minutos). Solo se guarda el momento de la
/// verificación, nunca la contraseña.
class DeleteAccountViewModel extends Notifier<DeleteAccountState> {
  /// Margen ante el límite de 5 minutos del servidor.
  static const Duration reauthenticationWindow = Duration(
    minutes: 4,
    seconds: 30,
  );

  DateTime? _reauthenticatedAt;

  @override
  DeleteAccountState build() => const DeleteAccountState();

  void setPassword(String value) =>
      state = state.copyWith(password: value, error: () => null);

  Future<void> submit() async {
    if (!state.canSubmit) return;
    if (state.step == DeleteAccountStep.retry && !_recentlyReauthenticated) {
      // Se venció la verificación: hay que escribir la contraseña de nuevo.
      _reauthenticatedAt = null;
      state = state.copyWith(
        step: DeleteAccountStep.password,
        error: () => DeleteAccountError.reauthenticate,
      );
      return;
    }
    state = state.copyWith(isSubmitting: true, error: () => null);

    if (!_recentlyReauthenticated) {
      try {
        await ref
            .read(authRepositoryProvider)
            .reauthenticate(password: state.password);
      } on AuthFailureException catch (error) {
        if (!ref.mounted) return;
        state = state.copyWith(
          step: DeleteAccountStep.password,
          isSubmitting: false,
          error: () => switch (error.failure) {
            AuthFailure.invalidCredentials => DeleteAccountError.wrongPassword,
            AuthFailure.network => DeleteAccountError.network,
            AuthFailure.rateLimited => DeleteAccountError.rateLimited,
            _ => DeleteAccountError.unknown,
          },
        );
        return;
      }
      _reauthenticatedAt = ref.read(clockProvider).now();
      if (!ref.mounted) return;
      // La contraseña ya no hace falta: no se conserva en el estado.
      state = state.copyWith(password: '');
    }

    final account = ref.read(accountRepositoryProvider);
    try {
      await account.deleteStoredFiles();
      await account.deleteAccount();
    } on AccountDeletionException catch (error) {
      if (!ref.mounted) return;
      if (error.failure == AccountDeletionFailure.reauthenticationRequired) {
        _reauthenticatedAt = null;
        state = state.copyWith(
          step: DeleteAccountStep.password,
          isSubmitting: false,
          error: () => DeleteAccountError.reauthenticate,
        );
        return;
      }
      state = state.copyWith(
        step: _recentlyReauthenticated
            ? DeleteAccountStep.retry
            : DeleteAccountStep.password,
        isSubmitting: false,
        error: () => _recentlyReauthenticated
            ? DeleteAccountError.interrupted
            : DeleteAccountError.reauthenticate,
      );
      return;
    }

    await ref.read(accountActionsProvider).completeAccountDeletion();
    if (!ref.mounted) return;
    state = state.copyWith(step: DeleteAccountStep.done, isSubmitting: false);
  }

  bool get _recentlyReauthenticated {
    final at = _reauthenticatedAt;
    if (at == null) return false;
    return ref.read(clockProvider).now().difference(at) <
        reauthenticationWindow;
  }
}
