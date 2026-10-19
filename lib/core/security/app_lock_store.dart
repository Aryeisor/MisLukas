import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'database_key_store.dart';

/// Preferencia "Ingresar con huella, rostro o PIN" (docs/07 §7.7), en el
/// almacenamiento seguro: bloquea la app al reabrirla y permite volver a
/// entrar desde el login sin contraseña. No hay PIN propio ni nada que lo
/// reemplace: solo si está activa.
///
/// Acompaña a los datos del dueño de la base local: sobrevive al cierre de
/// sesión que guarda la sesión, y el borrado total la quita ([clear], docs/08
/// §8.8.4). Así, quien entra después de un borrado no la hereda.
abstract interface class AppLockStore {
  Future<bool> readEnabled();

  Future<void> writeEnabled(bool enabled);

  Future<void> clear();
}

class SecureAppLockStore implements AppLockStore {
  const SecureAppLockStore([this._storage = DatabaseKeyStore.defaultStorage]);

  /// Nombre de la entrada en el almacenamiento seguro.
  static const String enabledKey = 'mislukas.app_lock_enabled';

  final FlutterSecureStorage _storage;

  @override
  Future<bool> readEnabled() async =>
      await _storage.read(key: enabledKey) == 'true';

  @override
  Future<void> writeEnabled(bool enabled) => enabled
      ? _storage.write(key: enabledKey, value: 'true')
      : _storage.delete(key: enabledKey);

  @override
  Future<void> clear() => _storage.delete(key: enabledKey);
}

final appLockStoreProvider = Provider<AppLockStore>(
  (ref) => const SecureAppLockStore(),
);

/// Preferencia leída en main() antes de abrir la app: al arrancar en frío se
/// decide el bloqueo sin esperar al almacenamiento seguro.
final initialAppLockEnabledProvider = Provider<bool>((ref) => false);
