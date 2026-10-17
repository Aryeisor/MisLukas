import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../security/database_key_store.dart';

/// Nombre del archivo de la base local.
const String databaseFileName = 'mislukas.sqlite';

/// Carpeta de las imágenes de recibos, junto a la base (Fase 6).
const String receiptsDirectoryName = 'recibos';

/// Archivos de la base: el principal y los temporales de SQLite.
const List<String> localDatabaseFiles = [
  databaseFileName,
  '$databaseFileName-wal',
  '$databaseFileName-shm',
  '$databaseFileName-journal',
];

/// Borra los archivos de la base en [directory] (los que existan).
Future<void> deleteDatabaseFiles(Directory directory) async {
  for (final name in localDatabaseFiles) {
    final file = File(p.join(directory.path, name));
    if (await file.exists()) await file.delete();
  }
}

/// Si no hay clave guardada, una base que haya quedado en [directory] (de un
/// borrado incompleto) no se puede leer: se borra antes de crear la nueva.
Future<void> deleteStaleDatabase(
  DatabaseKeyStore keyStore,
  Directory directory,
) async {
  if (await keyStore.hasStoredKey()) return;
  await deleteDatabaseFiles(directory);
}

/// Abre la base local cifrada en el directorio de soporte de la aplicación
/// (privado y no visible para el usuario). La clave se lee del almacenamiento
/// seguro la primera vez que se usa la base.
QueryExecutor openEncryptedDatabase(DatabaseKeyStore keyStore) {
  return LazyDatabase(() async {
    final directory = await getApplicationSupportDirectory();
    await deleteStaleDatabase(keyStore, directory);
    final key = await keyStore.getOrCreateKey();
    return openEncryptedFile(
      File(p.join(directory.path, databaseFileName)),
      hexKey: key,
    );
  });
}

/// Abre [file] cifrado con [hexKey] en un isolate de fondo, como recomienda
/// la documentación de Drift.
QueryExecutor openEncryptedFile(File file, {required String hexKey}) {
  return NativeDatabase.createInBackground(
    file,
    setup: (database) => applyEncryptionKey(database, hexKey),
  );
}

/// Primer paso al abrir la conexión, antes de cualquier otra operación.
///
/// `PRAGMA key` no admite parámetros, por eso es la única sentencia que se
/// arma con el valor dentro del texto; la clave se valida antes para que solo
/// contenga caracteres hexadecimales (docs/08 §8.6).
void applyEncryptionKey(Database database, String hexKey) {
  assert(
    hasCipherSupport(database),
    'SQLite no tiene cifrado: revisa hooks > user_defines > sqlite3 > source: '
    'sqlite3mc en pubspec.yaml.',
  );
  if (!isValidDatabaseKey(hexKey)) {
    // Sin incluir la clave en el mensaje.
    throw ArgumentError('Clave de cifrado con formato inválido.');
  }
  database.execute("PRAGMA key = '$hexKey';");
  // Lee el esquema para fallar de inmediato si la clave no corresponde.
  database.select('SELECT count(*) FROM sqlite_master;');
}

/// SQLite estándar no conoce `PRAGMA cipher`; SQLite3MultipleCiphers sí.
bool hasCipherSupport(Database database) {
  return database.select('PRAGMA cipher;').isNotEmpty;
}
