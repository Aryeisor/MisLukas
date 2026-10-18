import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/database/app_database.dart';
import 'package:mislukas/core/database/database_connection.dart';
import 'package:mislukas/core/database/local_data_wiper.dart';
import 'package:mislukas/core/security/database_key_store.dart';
import 'package:mislukas/core/security/device_session_store.dart';
import 'package:mislukas/core/security/receipt_key_store.dart';
import 'package:mislukas/features/budgets/data/drift_budget_alert_log.dart';
import 'package:mislukas/features/budgets/domain/entities/budget_alert.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';
import 'package:mislukas/features/onboarding/data/drift_onboarding_repository.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory directory;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('mislukas_wiper_');
  });
  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('cierra la base y borra archivos, recibos, claves y dueño', () async {
    const storage = FlutterSecureStorage();
    final keyStore = DatabaseKeyStore(storage);
    final receiptKeyStore = ReceiptKeyStore(storage);
    const sessionStore = SecureDeviceSessionStore(storage);
    final firstKey = await keyStore.getOrCreateKey();
    final firstReceiptKey = await receiptKeyStore.getOrCreateKey();
    await sessionStore.writeOwner('usuario-1');

    for (final name in FileLocalDataWiper.databaseFiles) {
      await File(p.join(directory.path, name)).writeAsString('datos');
    }
    final receipts = Directory(p.join(directory.path, receiptsDirectoryName));
    await File(p.join(receipts.path, 'r1.enc')).create(recursive: true);
    await File(p.join(receipts.path, 'tmp', 'r2.jpg')).create(recursive: true);
    final other = File(p.join(directory.path, 'otro.txt'))
      ..writeAsStringSync('no se toca');

    final events = <String>[];
    final wiper = FileLocalDataWiper(
      closeDatabase: () async => events.add('close'),
      directory: () async => directory,
      keyStore: keyStore,
      receiptKeyStore: receiptKeyStore,
      sessionStore: sessionStore,
      onWiped: () => events.add('wiped'),
      cancelNotifications: () async => events.add('notifications'),
    );

    await wiper.wipe();

    expect(events, ['notifications', 'close', 'wiped']);
    for (final name in FileLocalDataWiper.databaseFiles) {
      expect(File(p.join(directory.path, name)).existsSync(), isFalse);
    }
    expect(receipts.existsSync(), isFalse);
    expect(other.existsSync(), isTrue);
    expect(await storage.read(key: DatabaseKeyStore.storageKey), isNull);
    expect(await storage.read(key: ReceiptKeyStore.storageKey), isNull);
    expect(await receiptKeyStore.readKey(), isNull);
    expect(await sessionStore.readOwner(), isNull);
    // La próxima base y las próximas imágenes usan claves nuevas.
    expect(await keyStore.getOrCreateKey(), isNot(firstKey));
    expect(await receiptKeyStore.getOrCreateKey(), isNot(firstReceiptKey));
  });

  test('la marca de la bienvenida se va con el archivo de la base', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final file = File(p.join(directory.path, databaseFileName));
    final db = AppDatabase(NativeDatabase(file));
    await DriftOnboardingRepository(db).markWelcomeDone();
    expect(await DriftOnboardingRepository(db).isWelcomeDone(), isTrue);

    await FileLocalDataWiper(
      closeDatabase: db.close,
      directory: () async => directory,
      keyStore: DatabaseKeyStore(const FlutterSecureStorage()),
      receiptKeyStore: ReceiptKeyStore(const FlutterSecureStorage()),
      sessionStore: const SecureDeviceSessionStore(FlutterSecureStorage()),
      onWiped: () {},
    ).wipe();

    // La base nueva arranca sin la marca: la bienvenida se decide otra vez.
    final fresh = AppDatabase(NativeDatabase(file));
    addTearDown(fresh.close);
    expect(await DriftOnboardingRepository(fresh).isWelcomeDone(), isFalse);
  });

  test('las alertas registradas se van con el archivo de la base', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final file = File(p.join(directory.path, databaseFileName));
    final db = AppDatabase(NativeDatabase(file));
    final september = DateTime(2026, 9);
    await DriftBudgetAlertLog(db).record(september, [
      (DefaultCategory.mercado.id, BudgetAlertThreshold.warning),
    ], at: DateTime.utc(2026, 9, 22));
    await DriftBudgetAlertLog(db).markBaseline();

    await FileLocalDataWiper(
      closeDatabase: db.close,
      directory: () async => directory,
      keyStore: DatabaseKeyStore(const FlutterSecureStorage()),
      receiptKeyStore: ReceiptKeyStore(const FlutterSecureStorage()),
      sessionStore: const SecureDeviceSessionStore(FlutterSecureStorage()),
      onWiped: () {},
    ).wipe();

    final fresh = AppDatabase(NativeDatabase(file));
    addTearDown(fresh.close);
    expect(await DriftBudgetAlertLog(fresh).sentFor(september), isEmpty);
    expect(await DriftBudgetAlertLog(fresh).hasBaseline(), isFalse);
  });

  test('si quitar las notificaciones falla, el borrado sigue', () async {
    var wiped = false;
    await FileLocalDataWiper(
      closeDatabase: () async {},
      directory: () async => directory,
      keyStore: DatabaseKeyStore(const FlutterSecureStorage()),
      receiptKeyStore: ReceiptKeyStore(const FlutterSecureStorage()),
      sessionStore: const SecureDeviceSessionStore(FlutterSecureStorage()),
      onWiped: () => wiped = true,
      cancelNotifications: () async => throw StateError('sin plugin'),
    ).wipe();
    expect(wiped, isTrue);
  });

  test('sin archivos no falla', () async {
    final wiper = FileLocalDataWiper(
      closeDatabase: () async {},
      directory: () async => directory,
      keyStore: DatabaseKeyStore(const FlutterSecureStorage()),
      receiptKeyStore: ReceiptKeyStore(const FlutterSecureStorage()),
      sessionStore: const SecureDeviceSessionStore(FlutterSecureStorage()),
      onWiped: () {},
    );
    await wiper.wipe();
  });

  test(
    'si la base no cierra, igual borra la clave, el dueño y los archivos',
    () async {
      const storage = FlutterSecureStorage();
      final keyStore = DatabaseKeyStore(storage);
      const sessionStore = SecureDeviceSessionStore(storage);
      await keyStore.getOrCreateKey();
      await sessionStore.writeOwner('usuario-1');
      await File(p.join(directory.path, databaseFileName)).writeAsString('x');
      var wiped = false;

      await FileLocalDataWiper(
        closeDatabase: () => Completer<void>().future,
        directory: () async => directory,
        keyStore: keyStore,
        receiptKeyStore: ReceiptKeyStore(const FlutterSecureStorage()),
        sessionStore: sessionStore,
        onWiped: () => wiped = true,
      ).wipe();

      expect(await keyStore.hasStoredKey(), isFalse);
      expect(await sessionStore.readOwner(), isNull);
      expect(
        File(p.join(directory.path, databaseFileName)).existsSync(),
        isFalse,
      );
      expect(wiped, isTrue);
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );

  test(
    'si falla el borrado de archivos, la clave y el dueño ya se borraron',
    () async {
      const storage = FlutterSecureStorage();
      final keyStore = DatabaseKeyStore(storage);
      const sessionStore = SecureDeviceSessionStore(storage);
      await keyStore.getOrCreateKey();
      await sessionStore.writeOwner('usuario-1');

      await FileLocalDataWiper(
        closeDatabase: () async {},
        directory: () async => throw const FileSystemException('sin acceso'),
        keyStore: keyStore,
        receiptKeyStore: ReceiptKeyStore(const FlutterSecureStorage()),
        sessionStore: sessionStore,
        onWiped: () {},
      ).wipe();

      expect(await keyStore.hasStoredKey(), isFalse);
      expect(await sessionStore.readOwner(), isNull);
    },
  );

  test(
    'una base que quedó sin su clave se descarta antes de abrir la nueva',
    () async {
      final keyStore = DatabaseKeyStore(const FlutterSecureStorage());
      final stale = File(p.join(directory.path, databaseFileName))
        ..writeAsStringSync('base de otra clave');

      await deleteStaleDatabase(keyStore, directory);
      expect(stale.existsSync(), isFalse);

      // Con clave guardada, la base se conserva.
      await keyStore.getOrCreateKey();
      stale.writeAsStringSync('base actual');
      await deleteStaleDatabase(keyStore, directory);
      expect(stale.existsSync(), isTrue);
    },
  );
}
