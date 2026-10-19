import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/security/receipt_key_store.dart';
import 'package:mislukas/features/movements/data/receipts/aes_gcm_receipt_cipher.dart';
import 'package:mislukas/features/movements/data/receipts/file_receipt_image_store.dart';
import 'package:mislukas/features/movements/domain/repositories/receipt_cipher.dart';
import 'package:mislukas/features/movements/domain/repositories/receipt_image_store.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory support;
  late Directory cache;
  late FileReceiptImageStore store;
  final photo = Uint8List.fromList(List.generate(2048, (i) => i % 256));

  FileReceiptImageStore storeWith(ReceiptCipher cipher, {int? maxBytes}) =>
      FileReceiptImageStore(
        directory: () async => support,
        cacheDirectory: () async => cache,
        cipher: cipher,
        maxBytes: maxBytes ?? FileReceiptImageStore.defaultMaxBytes,
      );

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    support = await Directory.systemTemp.createTemp('mislukas_support_');
    cache = await Directory.systemTemp.createTemp('mislukas_cache_');
    store = storeWith(
      AesGcmReceiptCipher(ReceiptKeyStore(const FlutterSecureStorage())),
    );
  });
  tearDown(() async {
    for (final directory in [support, cache]) {
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  });

  /// Foto que la cámara dejó en la caché.
  Future<String> cameraPhoto([String name = 'CAP123.jpg']) async {
    final file = File(p.join(cache.path, name));
    await file.writeAsBytes(photo);
    return file.path;
  }

  Directory receipts() => Directory(p.join(support.path, 'recibos'));
  Directory tmp() => Directory(p.join(support.path, 'recibos', 'tmp'));

  List<String> namesIn(Directory directory) => directory.existsSync()
      ? (directory.listSync().map((e) => p.basename(e.path)).toList()..sort())
      : [];

  group('stage', () {
    test('mueve la foto de la caché a la carpeta temporal privada', () async {
      final source = await cameraPhoto();
      final staged = await store.stage(source, receiptId: 'r1');

      expect(File(source).existsSync(), isFalse);
      expect(staged, p.join(tmp().path, 'r1.jpg'));
      expect(await File(staged).readAsBytes(), photo);
    });

    test('imagen muy grande: error y el origen se borra', () async {
      final source = await cameraPhoto();
      final small = storeWith(
        AesGcmReceiptCipher(ReceiptKeyStore(const FlutterSecureStorage())),
        maxBytes: 1024,
      );

      await expectLater(
        small.stage(source, receiptId: 'r1'),
        throwsA(
          isA<ReceiptImageException>().having(
            (e) => e.error,
            'error',
            ReceiptImageError.tooLarge,
          ),
        ),
      );
      expect(File(source).existsSync(), isFalse);
      expect(namesIn(tmp()), isEmpty);
    });

    test('un id con separadores de ruta se rechaza', () async {
      final source = await cameraPhoto();
      await expectLater(
        store.stage(source, receiptId: '../fuera'),
        throwsA(isA<ReceiptImageException>()),
      );
    });

    test('descartar borra la imagen temporal', () async {
      await store.stage(await cameraPhoto(), receiptId: 'r1');
      await store.discardStaged('r1');
      expect(namesIn(tmp()), isEmpty);
    });
  });

  group('encryptAndStore y read', () {
    test('deja solo el archivo cifrado y lo descifra en memoria', () async {
      final staged = await store.stage(await cameraPhoto(), receiptId: 'r1');
      final relative = await store.encryptAndStore(staged, receiptId: 'r1');

      expect(relative, 'recibos/r1.enc');
      expect(File(staged).existsSync(), isFalse);
      expect(namesIn(tmp()), isEmpty);
      expect(namesIn(receipts()), ['r1.enc', 'tmp']);

      final encrypted = await File(p.join(support.path, relative))
          .readAsBytes();
      expect(encrypted, isNot(photo));

      final image = await store.read(relative, receiptId: 'r1');
      expect(image, isA<ReceiptImageAvailable>());
      expect((image as ReceiptImageAvailable).bytes, photo);
    });

    test('si el cifrado falla, el temporal se borra igual', () async {
      final failing = storeWith(_FailingCipher());
      final staged = await failing.stage(await cameraPhoto(), receiptId: 'r1');

      await expectLater(
        failing.encryptAndStore(staged, receiptId: 'r1'),
        throwsA(
          isA<ReceiptImageException>().having(
            (e) => e.error,
            'error',
            ReceiptImageError.failed,
          ),
        ),
      );
      expect(File(staged).existsSync(), isFalse);
      expect(namesIn(receipts()), ['tmp']);
    });

    test('solo cifra imágenes de la carpeta temporal', () async {
      final outside = await cameraPhoto('otra.jpg');
      await expectLater(
        store.encryptAndStore(outside, receiptId: 'r1'),
        throwsA(isA<ReceiptImageException>()),
      );
      // Un archivo de afuera no se cifra ni se borra.
      expect(File(outside).existsSync(), isTrue);
      expect(namesIn(receipts()), isEmpty);
    });

    test('ruta null o archivo inexistente: no está en este celular', () async {
      expect(
        await store.read(null, receiptId: 'r1'),
        isA<ReceiptImageNotOnDevice>(),
      );
      expect(
        await store.read('recibos/r9.enc', receiptId: 'r9'),
        isA<ReceiptImageNotOnDevice>(),
      );
    });

    test(
      'archivo alterado, otro id o ruta inválida: no se puede leer',
      () async {
        final staged = await store.stage(await cameraPhoto(), receiptId: 'r1');
        final relative = await store.encryptAndStore(staged, receiptId: 'r1');

        expect(
          await store.read(relative, receiptId: 'r2'),
          isA<ReceiptImageUnreadable>(),
        );
        expect(
          await store.read('../mislukas.sqlite', receiptId: 'r1'),
          isA<ReceiptImageUnreadable>(),
        );

        final file = File(p.join(support.path, relative));
        final bytes = await file.readAsBytes();
        bytes[20] ^= 0xff;
        await file.writeAsBytes(bytes);
        expect(
          await store.read(relative, receiptId: 'r1'),
          isA<ReceiptImageUnreadable>(),
        );
      },
    );

    test('sin la clave (borrada al cerrar sesión): no se puede leer', () async {
      final staged = await store.stage(await cameraPhoto(), receiptId: 'r1');
      final relative = await store.encryptAndStore(staged, receiptId: 'r1');
      await ReceiptKeyStore(const FlutterSecureStorage()).deleteKey();

      final fresh = storeWith(
        AesGcmReceiptCipher(ReceiptKeyStore(const FlutterSecureStorage())),
      );
      expect(
        await fresh.read(relative, receiptId: 'r1'),
        isA<ReceiptImageUnreadable>(),
      );
    });

    test('delete borra la imagen cifrada', () async {
      final staged = await store.stage(await cameraPhoto(), receiptId: 'r1');
      final relative = await store.encryptAndStore(staged, receiptId: 'r1');
      await store.delete(relative);
      expect(namesIn(receipts()), ['tmp']);
      // Una ruta fuera de recibos/ se ignora.
      await store.delete('../mislukas.sqlite');
    });
  });

  group('cleanUp', () {
    Future<void> encrypted(String id) async {
      final staged = await store.stage(
        await cameraPhoto('CAP-$id.jpg'),
        receiptId: id,
      );
      await store.encryptAndStore(staged, receiptId: id);
    }

    test('borra huérfanas, temporales y escrituras a medias', () async {
      await encrypted('activo');
      await encrypted('huerfano');
      await store.stage(await cameraPhoto('CAP-t.jpg'), receiptId: 'temporal');
      await File(p.join(receipts().path, '.medias.tmp')).writeAsBytes([1]);

      await store.cleanUp(
        keepPaths: {'recibos/activo.enc'},
        keepReceiptIds: {},
      );

      expect(namesIn(receipts()), ['activo.enc', 'tmp']);
      expect(namesIn(tmp()), isEmpty);
    });

    test('no toca los recibos en curso', () async {
      await encrypted('en-curso');
      await store.stage(
        await cameraPhoto('CAP-c.jpg'),
        receiptId: 'capturando',
      );

      await store.cleanUp(
        keepPaths: {},
        keepReceiptIds: {'en-curso', 'capturando'},
      );

      expect(namesIn(receipts()), ['en-curso.enc', 'tmp']);
      expect(namesIn(tmp()), ['capturando.jpg']);
    });

    test(
      'borra las fotos que la cámara o la galería dejaron en la caché',
      () async {
        await cameraPhoto('CAP999.jpg');
        await cameraPhoto('scaled_IMG_1.jpg');
        final copy = Directory(
          p.join(cache.path, '3f2504e0-4f89-11d3-9a0c-0305e82c3301'),
        )..createSync();
        await File(p.join(copy.path, 'IMG_1.jpg')).writeAsBytes(photo);
        final other = File(p.join(cache.path, 'otro_plugin.db'))
          ..writeAsBytesSync([1]);

        await store.cleanUp(keepPaths: {}, keepReceiptIds: {});

        expect(namesIn(cache), ['otro_plugin.db']);
        expect(other.existsSync(), isTrue);
      },
    );
  });
}

class _FailingCipher implements ReceiptCipher {
  @override
  Future<Uint8List> encrypt(
    Uint8List clearBytes, {
    required List<int> associatedData,
  }) async => throw StateError('cifrado');

  @override
  Future<Uint8List> decrypt(
    Uint8List sealedBytes, {
    required List<int> associatedData,
  }) async => throw StateError('cifrado');
}
