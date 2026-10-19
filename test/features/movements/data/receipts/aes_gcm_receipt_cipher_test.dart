import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/security/receipt_key_store.dart';
import 'package:mislukas/features/movements/data/receipts/aes_gcm_receipt_cipher.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  final image = Uint8List.fromList(List.generate(4096, (i) => i % 251));
  final aad = utf8.encode('recibo-1');

  AesGcmReceiptCipher cipher() =>
      AesGcmReceiptCipher(ReceiptKeyStore(const FlutterSecureStorage()));

  test('ida y vuelta: descifra exactamente lo que cifró', () async {
    final subject = cipher();
    final sealed = await subject.encrypt(image, associatedData: aad);

    // nonce (12) + texto cifrado + MAC (16)
    expect(sealed.length, image.length + 12 + 16);
    expect(sealed, isNot(containsAllInOrder(image.sublist(0, 64))));
    expect(await subject.decrypt(sealed, associatedData: aad), image);
  });

  test('el nonce cambia en cada imagen', () async {
    final subject = cipher();
    final a = await subject.encrypt(image, associatedData: aad);
    final b = await subject.encrypt(image, associatedData: aad);
    expect(a.sublist(0, 12), isNot(b.sublist(0, 12)));
    expect(a, isNot(b));
  });

  test('un archivo alterado no se descifra', () async {
    final subject = cipher();
    final sealed = await subject.encrypt(image, associatedData: aad);
    sealed[100] ^= 0x01;
    await expectLater(
      subject.decrypt(sealed, associatedData: aad),
      throwsA(anything),
    );
  });

  test('con otro id de recibo (AAD) no se descifra', () async {
    final subject = cipher();
    final sealed = await subject.encrypt(image, associatedData: aad);
    await expectLater(
      subject.decrypt(sealed, associatedData: utf8.encode('recibo-2')),
      throwsA(anything),
    );
  });

  test('con otra clave no se descifra', () async {
    final sealed = await cipher().encrypt(image, associatedData: aad);
    // Se borra la clave (cerrar sesión) y se crea otra.
    final keys = ReceiptKeyStore(const FlutterSecureStorage());
    await keys.deleteKey();
    await keys.getOrCreateKey();
    await expectLater(
      AesGcmReceiptCipher(keys).decrypt(sealed, associatedData: aad),
      throwsA(anything),
    );
  });

  test('sin clave guardada no descifra ni crea una', () async {
    final sealed = await cipher().encrypt(image, associatedData: aad);
    final keys = ReceiptKeyStore(const FlutterSecureStorage());
    await keys.deleteKey();

    await expectLater(
      AesGcmReceiptCipher(keys).decrypt(sealed, associatedData: aad),
      throwsStateError,
    );
    expect(await keys.readKey(), isNull);
  });
}
