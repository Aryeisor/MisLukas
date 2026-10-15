import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/database/app_database.dart';
import 'package:mislukas/core/database/database_connection.dart';
import 'package:mislukas/core/security/database_key_store.dart';
import 'package:mislukas/features/movements/data/drift_movement_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../../helpers/domain_fixtures.dart';

void main() {
  // Valor que no debe aparecer en el archivo en texto plano.
  const secret = 'SecretoDeCamilaEnElMercado';

  late Directory directory;
  late File file;
  late String key;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mislukas_cifrado_');
    file = File(p.join(directory.path, databaseFileName));
    key = generateDatabaseKey(Random.secure());

    final db = AppDatabase(openEncryptedFile(file, hexKey: key));
    await DriftMovementRepository(db)
        .add(testMovement(id: 'm1', description: secret, amount: 87400));
    await db.close();
  });

  tearDown(() => directory.delete(recursive: true));

  test('SQLite3MultipleCiphers está disponible', () {
    final database = sqlite3.openInMemory();
    addTearDown(database.close);
    expect(hasCipherSupport(database), isTrue);
  });

  test('con la clave correcta se leen los datos', () async {
    final db = AppDatabase(openEncryptedFile(file, hexKey: key));
    addTearDown(db.close);
    final movement = await DriftMovementRepository(db).findById('m1');
    expect(movement!.description, secret);
  });

  test('sin la clave no se puede abrir', () {
    final database = sqlite3.open(file.path);
    addTearDown(database.close);
    expect(
      () => database.select('SELECT count(*) FROM sqlite_master'),
      throwsA(isA<SqliteException>()),
    );
  });

  test('con otra clave no se puede abrir', () {
    final database = sqlite3.open(file.path);
    addTearDown(database.close);
    expect(
      () => applyEncryptionKey(database, generateDatabaseKey(Random.secure())),
      throwsA(isA<SqliteException>()),
    );
  });

  test('con otra clave Drift tampoco abre la base', () async {
    final db = AppDatabase(
      openEncryptedFile(file, hexKey: generateDatabaseKey(Random.secure())),
    );
    addTearDown(db.close);
    await expectLater(db.select(db.movements).get(), throwsA(anything));
  });

  test('el archivo no contiene en texto plano los valores guardados', () {
    final bytes = file.readAsBytesSync();
    final content = latin1.decode(bytes);
    expect(content, isNot(contains(secret)));
    expect(content, isNot(contains('movimientos')));
    expect(content, isNot(startsWith('SQLite format 3')));
  });

  test('rechaza claves con formato inválido sin ejecutar el PRAGMA', () {
    final database = sqlite3.openInMemory();
    addTearDown(database.close);
    expect(
      () => applyEncryptionKey(database, "abc'; DROP TABLE x; --"),
      throwsArgumentError,
    );
  });
}
