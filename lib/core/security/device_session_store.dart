import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'database_key_store.dart';

/// Datos del dispositivo sobre la sesión, en el almacenamiento seguro
/// (Keystore / Keychain): el usuario dueño de la base local, si quedó una
/// recuperación de contraseña a medias y si la sesión guardada está en
/// espera del bloqueo del celular. Nunca se escriben en logs.
abstract interface class DeviceSessionStore {
  /// Id del usuario dueño de la base local; null si no hay dueño.
  Future<String?> readOwner();

  Future<void> writeOwner(String userId);

  Future<void> clearOwner();

  /// Se verificó un código de recuperación y la contraseña nueva aún no se
  /// guardó: la sesión guardada es temporal.
  Future<bool> readRecoveryInProgress();

  Future<void> writeRecoveryInProgress(bool inProgress);

  /// Id del usuario que cerró sesión con "Ingresar con huella, rostro o PIN"
  /// activo: su sesión sigue guardada, pero solo se usa después del diálogo
  /// del sistema. Null si no hay sesión en espera.
  Future<String?> readParkedUser();

  Future<void> writeParkedUser(String userId);

  Future<void> clearParkedUser();
}

class SecureDeviceSessionStore implements DeviceSessionStore {
  const SecureDeviceSessionStore([
    this._storage = DatabaseKeyStore.defaultStorage,
  ]);

  /// Nombres de las entradas en el almacenamiento seguro.
  static const String ownerKey = 'mislukas.local_owner';
  static const String recoveryKey = 'mislukas.recovery_in_progress';
  static const String parkedUserKey = 'mislukas.parked_session_user';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readOwner() => _storage.read(key: ownerKey);

  @override
  Future<void> writeOwner(String userId) =>
      _storage.write(key: ownerKey, value: userId);

  @override
  Future<void> clearOwner() => _storage.delete(key: ownerKey);

  @override
  Future<bool> readRecoveryInProgress() async =>
      await _storage.read(key: recoveryKey) == 'true';

  @override
  Future<void> writeRecoveryInProgress(bool inProgress) => inProgress
      ? _storage.write(key: recoveryKey, value: 'true')
      : _storage.delete(key: recoveryKey);

  @override
  Future<String?> readParkedUser() => _storage.read(key: parkedUserKey);

  @override
  Future<void> writeParkedUser(String userId) =>
      _storage.write(key: parkedUserKey, value: userId);

  @override
  Future<void> clearParkedUser() => _storage.delete(key: parkedUserKey);
}

final deviceSessionStoreProvider = Provider<DeviceSessionStore>(
  (ref) => const SecureDeviceSessionStore(),
);

/// Dueño de la base local leído en main() antes de abrir la app, para decidir
/// la pantalla inicial sin esperar al almacenamiento seguro.
final initialLocalOwnerProvider = Provider<String?>((ref) => null);

/// Usuario con la sesión en espera leído en main() (ver
/// [DeviceSessionStore.readParkedUser]): al arrancar en frío se muestra el
/// login en lugar de Inicio.
final initialParkedUserProvider = Provider<String?>((ref) => null);
