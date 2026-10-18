import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../../../core/security/receipt_key_store.dart';
import '../../domain/repositories/receipt_cipher.dart';

/// AES-256-GCM con la clave de recibos (docs/07 §7.5).
///
/// El resultado es `nonce (12 bytes) ‖ texto cifrado ‖ MAC (16 bytes)`, con un
/// nonce aleatorio por imagen. En la app, cryptography_flutter usa la
/// implementación nativa del sistema (Android: javax.crypto; iOS: CryptoKit);
/// en las pruebas, la de Dart.
class AesGcmReceiptCipher implements ReceiptCipher {
  AesGcmReceiptCipher(this._keys);

  final ReceiptKeyStore _keys;

  static const int nonceLength = 12;
  static const int macLength = 16;

  // Se pide en cada uso: Cryptography.instance la decide el plugin al iniciar.
  AesGcm get _algorithm => AesGcm.with256bits();

  @override
  Future<Uint8List> encrypt(
    Uint8List clearBytes, {
    required List<int> associatedData,
  }) async {
    final key = SecretKey(await _keys.getOrCreateKey());
    final box = await _algorithm.encrypt(
      clearBytes,
      secretKey: key,
      aad: associatedData,
    );
    return box.concatenation();
  }

  @override
  Future<Uint8List> decrypt(
    Uint8List sealedBytes, {
    required List<int> associatedData,
  }) async {
    final stored = await _keys.readKey();
    if (stored == null) throw StateError('Sin clave de recibos.');
    final box = SecretBox.fromConcatenation(
      sealedBytes,
      nonceLength: nonceLength,
      macLength: macLength,
      copy: false,
    );
    final clear = await _algorithm.decrypt(
      box,
      secretKey: SecretKey(stored),
      aad: associatedData,
    );
    return clear is Uint8List ? clear : Uint8List.fromList(clear);
  }
}
