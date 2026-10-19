import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/security/app_lock_clock.dart';
import '../../../../core/security/app_lock_store.dart';
import '../../../../core/security/device_authenticator.dart';
import '../../../../core/security/external_activity_tracker.dart';
import '../account_session_controller.dart';

/// Aviso de la pantalla de desbloqueo.
enum AppLockMessage {
  /// El usuario cerró el diálogo del sistema.
  canceled,

  /// El sistema pausó el desbloqueo por varios intentos fallidos.
  lockedOut,

  /// Otro error del sistema.
  failed,
}

/// Estado del bloqueo de la app con el bloqueo del celular (docs/07 §7.7).
class AppLockState {
  const AppLockState({
    required this.enabled,
    required this.hasSession,
    this.locked = false,
    this.deviceLockAvailable,
    this.authenticating = false,
    this.message,
    this.offerPending = false,
  });

  /// El usuario activó el bloqueo.
  final bool enabled;

  /// Hay una sesión (de este usuario o de otro, antes de confirmar el
  /// borrado). Sin sesión no hay bloqueo.
  final bool hasSession;

  /// Falta desbloquear.
  final bool locked;

  /// El celular tiene bloqueo de pantalla; null mientras se revisa.
  final bool? deviceLockAvailable;

  /// El diálogo del sistema está abierto.
  final bool authenticating;

  final AppLockMessage? message;

  /// Se acaba de iniciar sesión con contraseña y el bloqueo está apagado: se
  /// ofrece activarlo.
  final bool offerPending;

  /// Se puede mostrar la app. Sin bloqueo de pantalla en el celular, la
  /// protección se pausa (y se reanuda sola cuando el usuario lo configura).
  bool get contentVisible =>
      !(enabled && hasSession && locked && deviceLockAvailable != false);

  /// "Cerrar sesión" puede conservar la sesión guardada: el ajuste está activo
  /// y el celular tiene bloqueo de pantalla para volver a entrar desde el
  /// login.
  bool get canKeepSession => enabled && deviceLockAvailable == true;

  AppLockState copyWith({
    bool? enabled,
    bool? hasSession,
    bool? locked,
    bool? Function()? deviceLockAvailable,
    bool? authenticating,
    AppLockMessage? Function()? message,
    bool? offerPending,
  }) {
    return AppLockState(
      enabled: enabled ?? this.enabled,
      hasSession: hasSession ?? this.hasSession,
      locked: locked ?? this.locked,
      deviceLockAvailable: deviceLockAvailable != null
          ? deviceLockAvailable()
          : this.deviceLockAvailable,
      authenticating: authenticating ?? this.authenticating,
      message: message != null ? message() : this.message,
      offerPending: offerPending ?? this.offerPending,
    );
  }
}

final appLockProvider = NotifierProvider<AppLockController, AppLockState>(
  AppLockController.new,
);

/// Bloquea la app con el bloqueo del propio celular (docs/07 §7.7, docs/08
/// §8.8.2). No hay PIN propio: el sistema decide el método (huella, rostro o
/// el PIN, patrón o contraseña del celular) y controla los intentos.
///
/// - Al abrir la app en frío con sesión, queda bloqueada.
/// - Al volver de segundo plano, se bloquea si pasó [backgroundLimit] según
///   el reloj monotónico o la hora del sistema, o si la hora retrocedió. Si
///   salió por una acción de la propia app (permisos, galería, Ajustes o el
///   diálogo del sistema), el límite es [externalActivityLimit].
/// - Iniciar sesión con contraseña, o desde el login con el diálogo del
///   sistema, la deja desbloqueada.
/// - La misma preferencia habilita "Ingresar con huella, rostro o PIN" en el
///   login cuando la sesión quedó en espera (QuickSignInViewModel).
class AppLockController extends Notifier<AppLockState> {
  /// Tiempo en segundo plano que bloquea la app (RNF-08).
  static const Duration backgroundLimit = Duration(minutes: 5);

  /// Límite cuando la app salió por una acción propia.
  static const Duration externalActivityLimit = Duration(minutes: 30);

  /// Textos del diálogo del sistema.
  static const String unlockReason = 'Desbloquea para ver tus finanzas';
  static const String enableReason =
      'Confirma que eres tú para activar el ingreso con huella, rostro o PIN';
  static const String disableReason =
      'Confirma que eres tú para desactivar el ingreso con huella, rostro o '
      'PIN';

  Duration? _hiddenAtMonotonic;
  DateTime? _hiddenAtWall;
  bool _hiddenForExternalActivity = false;

  /// El sistema cerró el diálogo (la app salió): se vuelve a mostrar al
  /// volver.
  bool _retryOnResume = false;

  /// Se inició sesión con contraseña y aún no se ofreció (ni se activó) el
  /// ajuste: la oferta se decide con la preferencia de cada recarga.
  bool _offerEligible = false;

  DeviceAuthenticator get _authenticator =>
      ref.read(deviceAuthenticatorProvider);
  ExternalActivityTracker get _tracker =>
      ref.read(externalActivityTrackerProvider);
  AppLockClock get _clock => ref.read(appLockClockProvider);

  @override
  AppLockState build() {
    ref.listen(accountSessionProvider, _onSessionChanged);
    final enabled = ref.read(initialAppLockEnabledProvider);
    final hasSession =
        ref.read(accountSessionProvider) != AccountSessionStatus.signedOut;
    return AppLockState(
      enabled: enabled,
      hasSession: hasSession,
      // Arranque en frío: con sesión y bloqueo activo, no se ve nada.
      locked: enabled && hasSession,
    );
  }

  void _onSessionChanged(
    AccountSessionStatus? previous,
    AccountSessionStatus next,
  ) {
    if (next == AccountSessionStatus.signedOut) {
      _retryOnResume = false;
      _offerEligible = false;
      state = state.copyWith(
        hasSession: false,
        locked: false,
        authenticating: false,
        message: () => null,
        offerPending: false,
      );
      return;
    }
    final freshSignIn = previous == AccountSessionStatus.signedOut;
    if (freshSignIn) {
      _offerEligible = true;
      // Acaba de escribir su contraseña o de pasar el diálogo del sistema en
      // el login: no se le pide nada más.
      state = state.copyWith(
        hasSession: true,
        locked: false,
        message: () => null,
      );
    }
    // La preferencia sobrevive al cierre de sesión que guarda la sesión, pero
    // el borrado total y el borrado por otra cuenta la quitan: se lee de nuevo
    // al iniciar sesión y después de un borrado. Si está activa, no hay oferta
    // y la app queda desbloqueada en esta sesión; el bloqueo aplica desde la
    // siguiente apertura o regreso.
    if (freshSignIn || next == AccountSessionStatus.ready) {
      unawaited(_reloadEnabled());
    }
  }

  Future<void> _reloadEnabled() async {
    bool enabled;
    try {
      enabled = await ref.read(appLockStoreProvider).readEnabled();
    } catch (_) {
      enabled = state.enabled;
    }
    if (!ref.mounted || !state.hasSession) return;
    state = state.copyWith(
      enabled: enabled,
      offerPending: _offerEligible && !enabled,
    );
  }

  /// La app pasó a segundo plano.
  void onHide() {
    _hiddenAtMonotonic = _clock.monotonic;
    _hiddenAtWall = _clock.wall;
    _hiddenForExternalActivity = _tracker.takeOnHide();
  }

  /// La app volvió a primer plano.
  Future<void> onResume() async {
    final hiddenAtMonotonic = _hiddenAtMonotonic;
    final hiddenAtWall = _hiddenAtWall;
    _hiddenAtMonotonic = null;
    _hiddenAtWall = null;
    if (!state.enabled || !state.hasSession) return;

    if (!state.locked && hiddenAtMonotonic != null && hiddenAtWall != null) {
      final limit = _hiddenForExternalActivity
          ? externalActivityLimit
          : backgroundLimit;
      final monotonic = _clock.monotonic - hiddenAtMonotonic;
      final wall = _clock.wall.difference(hiddenAtWall);
      // La hora del sistema que retrocede no se puede comparar: se bloquea.
      if (monotonic >= limit || wall >= limit || wall.isNegative) {
        lock();
      }
    }
    if (state.locked && !state.authenticating && _retryOnResume) {
      await engage();
    }
  }

  /// Bloquea la app y muestra el diálogo del sistema al mostrarse.
  void lock() {
    if (!state.enabled || !state.hasSession) return;
    _retryOnResume = false;
    state = state.copyWith(
      locked: true,
      deviceLockAvailable: () => null,
      message: () => null,
    );
    unawaited(engage());
  }

  /// Revisa si el celular tiene bloqueo de pantalla y muestra el diálogo del
  /// sistema. Sin bloqueo de pantalla, la protección se pausa: la app queda
  /// desbloqueada y se vuelve a revisar en el próximo bloqueo (al abrir en
  /// frío o después de 5 minutos fuera).
  Future<void> engage() async {
    if (!state.locked || state.authenticating) return;
    final available = await _authenticator.hasDeviceLock();
    if (!ref.mounted) return;
    state = state.copyWith(
      locked: available ? null : false,
      deviceLockAvailable: () => available,
    );
    if (available) await unlock();
  }

  /// Muestra el diálogo del sistema para desbloquear.
  Future<void> unlock() async {
    if (!state.locked || state.authenticating) return;
    _retryOnResume = false;
    state = state.copyWith(authenticating: true, message: () => null);
    final result = await _tracker.run(
      () => _authenticator.authenticate(unlockReason),
    );
    if (!ref.mounted) return;
    state = switch (result) {
      DeviceAuthResult.success => state.copyWith(
        locked: false,
        authenticating: false,
      ),
      DeviceAuthResult.noDeviceLock => state.copyWith(
        locked: false,
        authenticating: false,
        deviceLockAvailable: () => false,
      ),
      DeviceAuthResult.interrupted => state.copyWith(
        authenticating: false,
        message: () => AppLockMessage.canceled,
      ),
      DeviceAuthResult.canceled => state.copyWith(
        authenticating: false,
        message: () => AppLockMessage.canceled,
      ),
      DeviceAuthResult.lockedOut => state.copyWith(
        authenticating: false,
        message: () => AppLockMessage.lockedOut,
      ),
      DeviceAuthResult.failed => state.copyWith(
        authenticating: false,
        message: () => AppLockMessage.failed,
      ),
    };
    if (result == DeviceAuthResult.interrupted) _retryOnResume = true;
  }

  /// Revisa si el celular tiene bloqueo de pantalla (Perfil).
  Future<bool> refreshDeviceLock() async {
    final available = await _authenticator.hasDeviceLock();
    if (ref.mounted) {
      state = state.copyWith(deviceLockAvailable: () => available);
    }
    return available;
  }

  /// Activa el bloqueo desde la oferta, justo después de iniciar sesión con
  /// contraseña: no se abre el diálogo del sistema, para que no parezca un
  /// segundo factor. Aplica desde la siguiente apertura o regreso. Devuelve
  /// false si no se pudo guardar.
  Future<bool> enableAfterSignIn() async {
    try {
      await ref.read(appLockStoreProvider).writeEnabled(true);
    } catch (_) {
      return false;
    }
    _offerEligible = false;
    if (ref.mounted) {
      state = state.copyWith(enabled: true, locked: false, offerPending: false);
    }
    return true;
  }

  /// Activa el bloqueo desde el Perfil después de confirmar con el diálogo del
  /// sistema. La contraseña ya se verificó.
  Future<DeviceAuthResult> enable() async {
    final result = await _confirm(enableReason);
    if (result != DeviceAuthResult.success) return result;
    try {
      await ref.read(appLockStoreProvider).writeEnabled(true);
    } catch (_) {
      return DeviceAuthResult.failed;
    }
    _offerEligible = false;
    if (ref.mounted) {
      state = state.copyWith(enabled: true, locked: false, offerPending: false);
    }
    return result;
  }

  /// Desactiva el bloqueo después de confirmar con el diálogo del sistema.
  Future<DeviceAuthResult> disable() async {
    final result = await _confirm(disableReason);
    if (result != DeviceAuthResult.success) return result;
    try {
      await ref.read(appLockStoreProvider).writeEnabled(false);
    } catch (_) {
      return DeviceAuthResult.failed;
    }
    if (ref.mounted) state = state.copyWith(enabled: false, locked: false);
    return result;
  }

  Future<DeviceAuthResult> _confirm(String reason) async {
    if (state.authenticating) return DeviceAuthResult.interrupted;
    state = state.copyWith(authenticating: true);
    final result = await _tracker.run(
      () => _authenticator.authenticate(reason),
    );
    if (ref.mounted) {
      state = state.copyWith(
        authenticating: false,
        deviceLockAvailable: result == DeviceAuthResult.noDeviceLock
            ? () => false
            : null,
      );
    }
    return result;
  }

  /// Ya se ofreció activar el bloqueo en esta sesión.
  void dismissOffer() {
    _offerEligible = false;
    state = state.copyWith(offerPending: false);
  }
}
