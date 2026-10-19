import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/device_authenticator.dart';
import '../../../core/security/external_activity_tracker.dart';
import '../data/auth_providers.dart';
import '../domain/auth_failure.dart';
import 'app_lock/app_lock_controller.dart';
import 'parked_session.dart';

/// Aviso de "Ingresar con huella, rostro o PIN" en el login.
enum QuickSignInMessage {
  /// El usuario cerró el diálogo del sistema.
  canceled,

  /// El sistema pausó el desbloqueo por varios intentos fallidos.
  lockedOut,

  /// Otro error del sistema.
  failed,

  /// El servidor rechazó la sesión guardada: hay que usar la contraseña.
  sessionExpired,
}

/// Estado del ingreso con el bloqueo del celular desde el login.
class QuickSignInState {
  const QuickSignInState({
    required this.available,
    this.busy = false,
    this.message,
  });

  /// Se muestra el botón: el ajuste está activo, hay una sesión guardada en
  /// espera y el celular tiene bloqueo de pantalla.
  final bool available;

  /// El diálogo del sistema o la renovación de la sesión están en curso.
  final bool busy;

  final QuickSignInMessage? message;
}

final quickSignInViewModelProvider =
    NotifierProvider.autoDispose<QuickSignInViewModel, QuickSignInState>(
      QuickSignInViewModel.new,
    );

/// Ingreso desde el login con el bloqueo del celular (RF-12, docs/07 §7.7).
///
/// Después del diálogo del sistema, la sesión guardada se renueva con el
/// servidor. Si el servidor la rechaza (contraseña cambiada en otro celular,
/// cuenta eliminada), se pide la contraseña y los datos se conservan
/// cifrados, como en cualquier sesión revocada (docs/06 §6.6.4). Sin
/// conexión se entra igual: la sesión sigue guardada y se revisa al volver la
/// red.
///
/// No hay estado de éxito: al quitar la espera, el router lleva a Inicio.
class QuickSignInViewModel extends Notifier<QuickSignInState> {
  /// Texto del diálogo del sistema.
  static const String reason = 'Confirma que eres tú para ingresar';

  bool _busy = false;
  QuickSignInMessage? _message;

  @override
  QuickSignInState build() {
    final saved = ref.watch(savedSessionProvider);
    final lock = ref.watch(appLockProvider);
    return QuickSignInState(
      available: saved && lock.enabled && lock.deviceLockAvailable == true,
      busy: _busy,
      message: _message,
    );
  }

  void _emit({bool? busy, QuickSignInMessage? Function()? message}) {
    if (busy != null) _busy = busy;
    if (message != null) _message = message();
    state = QuickSignInState(
      available: state.available,
      busy: _busy,
      message: _message,
    );
  }

  /// Revisa si el celular tiene bloqueo de pantalla (al abrir el login y al
  /// volver a primer plano).
  Future<void> refreshDeviceLock() =>
      ref.read(appLockProvider.notifier).refreshDeviceLock();

  Future<void> signIn() async {
    if (!state.available || _busy) return;
    _emit(busy: true, message: () => null);
    final result = await ref
        .read(externalActivityTrackerProvider)
        .run(() => ref.read(deviceAuthenticatorProvider).authenticate(reason));
    if (!ref.mounted) return;

    switch (result) {
      case DeviceAuthResult.success:
        break;
      case DeviceAuthResult.noDeviceLock:
        _emit(busy: false);
        await refreshDeviceLock();
        return;
      case DeviceAuthResult.canceled || DeviceAuthResult.interrupted:
        _emit(busy: false, message: () => QuickSignInMessage.canceled);
        return;
      case DeviceAuthResult.lockedOut:
        _emit(busy: false, message: () => QuickSignInMessage.lockedOut);
        return;
      case DeviceAuthResult.failed:
        _emit(busy: false, message: () => QuickSignInMessage.failed);
        return;
    }

    try {
      await ref.read(authRepositoryProvider).resumeSession();
    } on AuthFailureException catch (error) {
      if (!ref.mounted) return;
      if (error.failure == AuthFailure.sessionExpired) {
        // La sesión ya se borró; los datos y el dueño se conservan.
        ref.read(parkedSessionProvider.notifier).clear();
        _emit(busy: false, message: () => QuickSignInMessage.sessionExpired);
        return;
      }
      // Sin conexión o el servidor no respondió: la sesión sigue guardada y
      // se entra igual (offline-first).
    }
    if (!ref.mounted) return;
    _emit(busy: false);
    ref.read(parkedSessionProvider.notifier).clear();
  }
}
