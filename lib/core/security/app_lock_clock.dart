import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Relojes del bloqueo por tiempo en segundo plano (docs/07 §7.7). Se usan
/// los dos porque ninguno basta solo: el monotónico puede no avanzar con el
/// celular en reposo profundo, y la hora del sistema la puede cambiar el
/// usuario. No es `clockProvider`: la fecha simulada de desarrollo no lo
/// afecta.
abstract interface class AppLockClock {
  /// Tiempo monotónico desde que arrancó la app.
  Duration get monotonic;

  /// Hora del sistema.
  DateTime get wall;
}

class SystemAppLockClock implements AppLockClock {
  SystemAppLockClock() : _stopwatch = Stopwatch()..start();

  final Stopwatch _stopwatch;

  @override
  Duration get monotonic => _stopwatch.elapsed;

  @override
  DateTime get wall => DateTime.now();
}

final appLockClockProvider = Provider<AppLockClock>(
  (ref) => SystemAppLockClock(),
);
