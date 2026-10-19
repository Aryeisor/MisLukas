import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lock_clock.dart';

/// Acciones que la propia app lanza fuera de ella: el diálogo de permisos, la
/// galería, los Ajustes del sistema o el diálogo de desbloqueo. Si la app pasa
/// a segundo plano por una de ellas, al volver se usa el límite largo del
/// bloqueo (docs/07 §7.7).
class ExternalActivityTracker {
  ExternalActivityTracker(this._clock);

  /// Tiempo para salir hacia los Ajustes después de abrirlos: openAppSettings
  /// responde de inmediato, sin esperar a que el usuario vuelva.
  static const Duration settingsLaunchWindow = Duration(seconds: 10);

  final AppLockClock _clock;
  int _running = 0;
  Duration? _settingsOpenedAt;

  /// Corre [action], que puede llevar la app a segundo plano y la regresa al
  /// terminar (permisos, galería, diálogo del sistema).
  Future<T> run<T>(Future<T> Function() action) async {
    _running++;
    try {
      return await action();
    } finally {
      _running--;
    }
  }

  /// La app va a abrir los Ajustes del sistema. Cuenta solo para la próxima
  /// salida a segundo plano.
  void markLeavingForSettings() => _settingsOpenedAt = _clock.monotonic;

  /// La app pasa a segundo plano: true si es por una acción propia. Consume
  /// la marca de los Ajustes.
  bool takeOnHide() {
    final openedAt = _settingsOpenedAt;
    _settingsOpenedAt = null;
    final settings =
        openedAt != null && _clock.monotonic - openedAt <= settingsLaunchWindow;
    return _running > 0 || settings;
  }
}

final externalActivityTrackerProvider = Provider<ExternalActivityTracker>(
  (ref) => ExternalActivityTracker(ref.read(appLockClockProvider)),
);
