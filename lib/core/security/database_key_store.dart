import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Clave de cifrado de la base local (docs/06 §6.5, docs/08 §8.8.1).
///
/// Son 32 bytes aleatorios de un generador criptográficamente seguro,
/// generados la primera vez y guardados solo en el almacenamiento seguro del
/// sistema (Keystore / Keychain). La clave nunca se escribe en logs.
class DatabaseKeyStore {
  DatabaseKeyStore(this._storage, {Random? random})
    : _random = random ?? Random.secure();

  /// Opciones del almacenamiento seguro (docs/07 §7.6): en iOS la clave solo
  /// es accesible con el dispositivo desbloqueado y no pasa a otro dispositivo
  /// al restaurar una copia de seguridad.
  static const FlutterSecureStorage defaultStorage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );

  /// Nombre de la entrada en el almacenamiento seguro.
  static const String storageKey = 'mislukas.database_key';

  /// Largo de la clave: 32 bytes (256 bits).
  static const int keyLengthBytes = 32;

  final FlutterSecureStorage _storage;
  final Random _random;
  Future<String>? _key;

  /// Clave en hexadecimal (64 caracteres). La genera y la guarda si no existe.
  /// Llamadas simultáneas comparten el mismo resultado, para no generar dos
  /// claves distintas.
  Future<String> getOrCreateKey() => _key ??= _loadOrCreate();

  /// Hay una clave válida guardada (la base actual se puede leer).
  Future<bool> hasStoredKey() async {
    final stored = await _storage.read(key: storageKey);
    return stored != null && isValidDatabaseKey(stored);
  }

  /// Borra la clave (cerrar sesión o eliminar la cuenta, docs/08 §8.8.4).
  Future<void> deleteKey() async {
    _key = null;
    await _storage.delete(key: storageKey);
  }

  Future<String> _loadOrCreate() async {
    try {
      final stored = await _storage.read(key: storageKey);
      if (stored != null && isValidDatabaseKey(stored)) return stored;

      final key = generateDatabaseKey(_random);
      await _storage.write(key: storageKey, value: key);
      return key;
    } catch (_) {
      // Permite reintentar si el almacenamiento falló.
      _key = null;
      rethrow;
    }
  }
}

final RegExp _hexKeyPattern = RegExp(
  '^[0-9a-f]{${DatabaseKeyStore.keyLengthBytes * 2}}\$',
);

/// La clave son exactamente 64 caracteres hexadecimales en minúscula.
bool isValidDatabaseKey(String key) => _hexKeyPattern.hasMatch(key);

/// 32 bytes de [random] en hexadecimal.
String generateDatabaseKey(Random random) {
  final buffer = StringBuffer();
  for (var i = 0; i < DatabaseKeyStore.keyLengthBytes; i++) {
    buffer.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}
