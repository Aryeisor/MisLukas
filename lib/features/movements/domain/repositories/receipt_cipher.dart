import 'dart:typed_data';

/// Cifrado autenticado de las imágenes de recibos (AES-GCM, docs/07 §7.5).
abstract interface class ReceiptCipher {
  /// Cifra [clearBytes] ligados a [associatedData] (el id del recibo).
  Future<Uint8List> encrypt(
    Uint8List clearBytes, {
    required List<int> associatedData,
  });

  /// Descifra [sealedBytes]. Lanza si el archivo fue alterado, si
  /// [associatedData] no coincide o si no hay clave.
  Future<Uint8List> decrypt(
    Uint8List sealedBytes, {
    required List<int> associatedData,
  });
}
