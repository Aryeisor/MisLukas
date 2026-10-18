import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'database_key_store.dart';

/// Clave AES-256 de las imágenes de recibos (docs/07 §7.5, docs/08 §8.8.1).
///
/// Es distinta de la clave de la base: si una se compromete, la otra no. Son
/// 32 bytes aleatorios de un generador criptográficamente seguro, guardados
/// solo en el almacenamiento seguro del sistema y borrados con los datos
/// locales. Nunca se escribe en logs.
class ReceiptKeyStore {
  ReceiptKeyStore(this._storage, {Random? random})
    : _random = random ?? Random.secure();

  /// Mismas opciones que la clave de la base: en iOS solo con el dispositivo
  /// desbloqueado y sin pasar a otro dispositivo.
  static const FlutterSecureStorage defaultStorage =
      DatabaseKeyStore.defaultStorage;

  /// Nombre de la entrada en el almacenamiento seguro.
  static const String storageKey = 'mislukas.receipt_key';

  /// Largo de la clave: 32 bytes (256 bits).
  static const int keyLengthBytes = 32;

  final FlutterSecureStorage _storage;
  final Random _random;
  Future<List<int>>? _key;

  /// La clave; la genera y la guarda si no existe.
  ///
  /// Es idempotente y serializada: las llamadas simultáneas esperan la misma
  /// creación y, antes de generar, se vuelve a leer lo guardado. Dos
  /// guardados seguidos nunca generan dos claves distintas.
  Future<List<int>> getOrCreateKey() => _key ??= _loadOrCreate();

  /// La clave guardada, sin crearla; null si no existe (las imágenes que haya
  /// no se pueden descifrar).
  Future<List<int>?> readKey() async {
    final pending = _key;
    if (pending != null) {
      try {
        return await pending;
      } catch (_) {
        return null;
      }
    }
    return _decode(await _storage.read(key: storageKey));
  }

  /// Borra la clave (cerrar sesión o eliminar la cuenta, docs/08 §8.8.4).
  Future<void> deleteKey() async {
    _key = null;
    await _storage.delete(key: storageKey);
  }

  Future<List<int>> _loadOrCreate() async {
    try {
      final stored = _decode(await _storage.read(key: storageKey));
      if (stored != null) return stored;

      final key = List<int>.generate(
        keyLengthBytes,
        (_) => _random.nextInt(256),
      );
      await _storage.write(key: storageKey, value: base64Encode(key));
      return key;
    } catch (_) {
      // Permite reintentar si el almacenamiento falló.
      _key = null;
      rethrow;
    }
  }

  static List<int>? _decode(String? stored) {
    if (stored == null) return null;
    try {
      final bytes = base64Decode(stored);
      return bytes.length == keyLengthBytes ? bytes : null;
    } on FormatException {
      return null;
    }
  }
}
