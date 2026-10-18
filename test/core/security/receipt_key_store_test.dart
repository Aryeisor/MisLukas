import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/security/receipt_key_store.dart';

void main() {
  test(
    'dos llamadas simultáneas usan la misma clave y una sola escritura',
    () async {
      final storage = _CountingStorage(delay: const Duration(milliseconds: 20));
      final store = ReceiptKeyStore(storage);

      final keys = await Future.wait([
        store.getOrCreateKey(),
        store.getOrCreateKey(),
        store.getOrCreateKey(),
      ]);

      expect(keys[0], hasLength(ReceiptKeyStore.keyLengthBytes));
      expect(keys[1], keys[0]);
      expect(keys[2], keys[0]);
      expect(storage.writes, 1);
    },
  );

  test('dos guardados seguidos no generan otra clave', () async {
    final storage = _CountingStorage();
    final store = ReceiptKeyStore(storage);
    final first = await store.getOrCreateKey();
    final second = await store.getOrCreateKey();
    // Otra instancia (por ejemplo, después de reiniciar la app) lee la misma.
    final third = await ReceiptKeyStore(storage).getOrCreateKey();

    expect(second, first);
    expect(third, first);
    expect(storage.writes, 1);
  });

  test('con una clave ya guardada no se genera otra', () async {
    final existing = List<int>.generate(32, (i) => i);
    final storage = _CountingStorage()
      ..values[ReceiptKeyStore.storageKey] = base64Encode(existing);

    expect(await ReceiptKeyStore(storage).getOrCreateKey(), existing);
    expect(storage.writes, 0);
  });

  test('readKey no crea la clave', () async {
    final storage = _CountingStorage();
    final store = ReceiptKeyStore(storage);
    expect(await store.readKey(), isNull);
    expect(storage.writes, 0);

    final key = await store.getOrCreateKey();
    expect(await store.readKey(), key);
  });

  test('después de borrarla se genera una clave nueva', () async {
    final storage = _CountingStorage();
    final store = ReceiptKeyStore(storage);
    final first = await store.getOrCreateKey();

    await store.deleteKey();
    expect(storage.values, isEmpty);
    expect(await store.readKey(), isNull);
    expect(await store.getOrCreateKey(), isNot(first));
  });

  test('un valor guardado inválido se reemplaza', () async {
    final storage = _CountingStorage()
      ..values[ReceiptKeyStore.storageKey] = 'no-es-base64';
    final key = await ReceiptKeyStore(storage).getOrCreateKey();
    expect(key, hasLength(32));
  });

  test(
    'si el almacenamiento falla, el siguiente intento vuelve a probar',
    () async {
      final storage = _CountingStorage()..failNextWrite = true;
      final store = ReceiptKeyStore(storage);
      await expectLater(store.getOrCreateKey(), throwsStateError);
      expect(await store.getOrCreateKey(), hasLength(32));
    },
  );

  test('es distinta de la clave de la base', () {
    expect(ReceiptKeyStore.storageKey, isNot('mislukas.database_key'));
  });
}

/// Almacenamiento seguro en memoria que cuenta las escrituras.
class _CountingStorage implements FlutterSecureStorage {
  _CountingStorage({this.delay = Duration.zero});

  final Duration delay;
  final Map<String, String> values = {};
  int writes = 0;
  bool failNextWrite = false;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    await Future<void>.delayed(delay);
    return values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    await Future<void>.delayed(delay);
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('almacenamiento');
    }
    writes++;
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
