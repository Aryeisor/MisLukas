import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'database_key_store.dart';

// Almacenamiento de la sesión de Supabase en el Keystore / Keychain
// (docs/06 §6.7.1, docs/08 §8.2.5). Reemplaza el almacenamiento por defecto
// de supabase_flutter, que usa SharedPreferences. Nunca se escriben en logs
// los valores guardados.

/// Sesión de Supabase Auth (tokens de acceso y de renovación).
class SecureSessionStorage extends LocalStorage {
  const SecureSessionStorage([
    this._storage = DatabaseKeyStore.defaultStorage,
  ]);

  /// Nombre de la entrada en el almacenamiento seguro.
  static const String storageKey = 'mislukas.auth_session';

  final FlutterSecureStorage _storage;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() => _storage.containsKey(key: storageKey);

  @override
  Future<String?> accessToken() => _storage.read(key: storageKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: storageKey, value: persistSessionString);

  @override
  Future<void> removePersistedSession() => _storage.delete(key: storageKey);
}

/// Verificador del flujo PKCE.
class SecurePkceStorage extends GotrueAsyncStorage {
  const SecurePkceStorage([this._storage = DatabaseKeyStore.defaultStorage]);

  /// Prefijo de las entradas en el almacenamiento seguro.
  static const String keyPrefix = 'mislukas.pkce.';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> getItem({required String key}) =>
      _storage.read(key: '$keyPrefix$key');

  @override
  Future<void> setItem({required String key, required String value}) =>
      _storage.write(key: '$keyPrefix$key', value: value);

  @override
  Future<void> removeItem({required String key}) =>
      _storage.delete(key: '$keyPrefix$key');
}
