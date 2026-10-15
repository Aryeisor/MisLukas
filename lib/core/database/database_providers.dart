import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../security/database_key_store.dart';
import 'app_database.dart';
import 'database_connection.dart';

/// Clave de cifrado de la base local.
final databaseKeyStoreProvider = Provider<DatabaseKeyStore>(
  (ref) => DatabaseKeyStore(DatabaseKeyStore.defaultStorage),
);

/// Base local cifrada. Se abre al primer uso y se cierra con el contenedor.
/// En pruebas se sobrescribe con una base en memoria.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase(
    openEncryptedDatabase(ref.watch(databaseKeyStoreProvider)),
  );
  ref.onDispose(database.close);
  return database;
});
