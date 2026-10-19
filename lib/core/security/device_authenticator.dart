import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

/// Resultado del diálogo de desbloqueo del sistema.
enum DeviceAuthResult {
  /// El usuario se identificó.
  success,

  /// El usuario cerró el diálogo o se venció su tiempo.
  canceled,

  /// El sistema cerró el diálogo (por ejemplo, la app pasó a segundo plano).
  interrupted,

  /// El sistema pausó el desbloqueo por varios intentos fallidos.
  lockedOut,

  /// El celular no tiene bloqueo de pantalla.
  noDeviceLock,

  /// Cualquier otro error.
  failed,
}

/// Bloqueo del propio celular (docs/07 §7.7): huella, rostro o el PIN,
/// patrón o contraseña del sistema. El sistema decide el método y controla
/// los intentos; la app solo recibe si funcionó. Nada se escribe en logs.
abstract interface class DeviceAuthenticator {
  /// El celular tiene bloqueo de pantalla.
  Future<bool> hasDeviceLock();

  /// Muestra el diálogo del sistema con [reason].
  Future<DeviceAuthResult> authenticate(String reason);
}

/// [DeviceAuthenticator] con local_auth.
///
/// `isDeviceSupported` es `KeyguardManager.isDeviceSecure` o biometría
/// registrada en Android, que no existe sin un bloqueo seguro, y
/// `deviceOwnerAuthentication` en iOS: sin bloqueo de pantalla da false.
class LocalAuthDeviceAuthenticator implements DeviceAuthenticator {
  LocalAuthDeviceAuthenticator([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> hasDeviceLock() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<DeviceAuthResult> authenticate(String reason) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Desbloquea MisLukas',
            signInHint: 'Usa el bloqueo de tu celular',
            cancelButton: 'Cancelar',
          ),
          IOSAuthMessages(cancelButton: 'Cancelar'),
        ],
        // Huella o rostro si hay; si no, o si fallan, el PIN, patrón o
        // contraseña del celular en el mismo diálogo.
        biometricOnly: false,
        // Sin confirmación extra después del rostro.
        sensitiveTransaction: false,
      );
      return ok ? DeviceAuthResult.success : DeviceAuthResult.canceled;
    } on LocalAuthException catch (error) {
      return switch (error.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.timeout ||
        LocalAuthExceptionCode.userRequestedFallback =>
          DeviceAuthResult.canceled,
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.uiUnavailable ||
        LocalAuthExceptionCode.authInProgress => DeviceAuthResult.interrupted,
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout => DeviceAuthResult.lockedOut,
        LocalAuthExceptionCode.noCredentialsSet =>
          DeviceAuthResult.noDeviceLock,
        _ => DeviceAuthResult.failed,
      };
    } catch (_) {
      return DeviceAuthResult.failed;
    }
  }
}

final deviceAuthenticatorProvider = Provider<DeviceAuthenticator>(
  (ref) => LocalAuthDeviceAuthenticator(),
);
