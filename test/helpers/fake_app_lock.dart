import 'package:mislukas/core/security/app_lock_clock.dart';
import 'package:mislukas/core/security/app_lock_store.dart';
import 'package:mislukas/core/security/device_authenticator.dart';

/// Bloqueo del celular falso: [hasLock] dice si el celular tiene bloqueo de
/// pantalla y [nextResults] lo que responde el diálogo del sistema (por
/// defecto, éxito).
class FakeDeviceAuthenticator implements DeviceAuthenticator {
  FakeDeviceAuthenticator({this.hasLock = true});

  bool hasLock;

  /// Respuestas del diálogo, en orden; vacía responde [DeviceAuthResult.success].
  final List<DeviceAuthResult> nextResults = [];

  /// Textos con que se abrió el diálogo, en orden.
  final List<String> prompts = [];

  /// Se llama al abrir el diálogo, antes de responder (por ejemplo, para
  /// simular que la app pasa a segundo plano).
  void Function()? onPrompt;

  @override
  Future<bool> hasDeviceLock() async => hasLock;

  @override
  Future<DeviceAuthResult> authenticate(String reason) async {
    prompts.add(reason);
    onPrompt?.call();
    await Future<void>.delayed(Duration.zero);
    if (!hasLock) return DeviceAuthResult.noDeviceLock;
    return nextResults.isEmpty
        ? DeviceAuthResult.success
        : nextResults.removeAt(0);
  }
}

/// [AppLockStore] en memoria.
class MemoryAppLockStore implements AppLockStore {
  MemoryAppLockStore({this.enabled = false});

  bool enabled;

  @override
  Future<bool> readEnabled() async => enabled;

  @override
  Future<void> writeEnabled(bool value) async => enabled = value;

  @override
  Future<void> clear() async => enabled = false;
}

/// Relojes del bloqueo manejados a mano. [advance] mueve los dos; los otros,
/// uno solo (el monotónico se detiene con el celular dormido; la hora del
/// sistema la puede cambiar el usuario).
class FakeAppLockClock implements AppLockClock {
  FakeAppLockClock({DateTime? wall}) : wall = wall ?? DateTime(2026, 10, 19, 9);

  @override
  Duration monotonic = Duration.zero;

  @override
  DateTime wall;

  void advance(Duration duration) {
    monotonic += duration;
    wall = wall.add(duration);
  }

  void advanceMonotonic(Duration duration) => monotonic += duration;

  void advanceWall(Duration duration) => wall = wall.add(duration);
}
