import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/security/database_key_store.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('genera 32 bytes en hexadecimal y los guarda', () async {
    const storage = FlutterSecureStorage();
    final key = await DatabaseKeyStore(storage).getOrCreateKey();

    expect(key, hasLength(64));
    expect(isValidDatabaseKey(key), isTrue);
    expect(await storage.read(key: DatabaseKeyStore.storageKey), key);
  });

  test('la segunda vez devuelve la misma clave', () async {
    const storage = FlutterSecureStorage();
    final first = await DatabaseKeyStore(storage).getOrCreateKey();
    final second = await DatabaseKeyStore(storage).getOrCreateKey();
    expect(second, first);
  });

  test('llamadas simultáneas comparten la clave', () async {
    final store = DatabaseKeyStore(const FlutterSecureStorage());
    final keys = await Future.wait([
      store.getOrCreateKey(),
      store.getOrCreateKey(),
    ]);
    expect(keys[0], keys[1]);
  });

  test('reemplaza un valor guardado inválido', () async {
    FlutterSecureStorage.setMockInitialValues({
      DatabaseKeyStore.storageKey: 'corta',
    });
    final key = await DatabaseKeyStore(const FlutterSecureStorage())
        .getOrCreateKey();
    expect(isValidDatabaseKey(key), isTrue);
  });

  test('borrar la clave obliga a generar otra', () async {
    const storage = FlutterSecureStorage();
    final store = DatabaseKeyStore(storage);
    final first = await store.getOrCreateKey();
    await store.deleteKey();
    expect(await storage.read(key: DatabaseKeyStore.storageKey), isNull);
    expect(await store.getOrCreateKey(), isNot(first));
  });

  test('cada byte sale del generador aleatorio', () {
    expect(generateDatabaseKey(_ConstantRandom(0xab)), 'ab' * 32);
    final keys = {
      for (var i = 0; i < 20; i++) generateDatabaseKey(Random.secure()),
    };
    expect(keys, hasLength(20));
  });
}

class _ConstantRandom implements Random {
  _ConstantRandom(this.value);

  final int value;

  @override
  int nextInt(int max) => value;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}
