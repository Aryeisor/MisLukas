import 'dart:typed_data';

/// Por qué no se pudo guardar una imagen de recibo.
enum ReceiptImageError {
  /// Pesa más que el límite (5 MB, el mismo del bucket de Storage).
  tooLarge,

  /// No se pudo leer, mover o cifrar.
  failed,
}

class ReceiptImageException implements Exception {
  const ReceiptImageException(this.error);

  final ReceiptImageError error;

  // Sin la ruta del archivo (docs/08 §8.8.5).
  @override
  String toString() => 'ReceiptImageException(${error.name})';
}

/// Imagen de un recibo lista para mostrar.
sealed class ReceiptImage {
  const ReceiptImage();
}

/// Imagen descifrada en memoria. Nunca se escribe descifrada en disco.
class ReceiptImageAvailable extends ReceiptImage {
  const ReceiptImageAvailable(this.bytes);

  final Uint8List bytes;
}

/// El recibo no tiene imagen en este celular: llegó por sincronización desde
/// otro dispositivo, o el archivo ya no existe.
class ReceiptImageNotOnDevice extends ReceiptImage {
  const ReceiptImageNotOnDevice();
}

/// La imagen existe, pero no se pudo descifrar (sin clave o archivo alterado).
class ReceiptImageUnreadable extends ReceiptImage {
  const ReceiptImageUnreadable();
}

/// Imágenes de recibos en el almacenamiento privado de la app (docs/07 §7.5).
///
/// Se guardan cifradas (`recibos/<id>.enc`). Sin cifrar, la imagen solo
/// existe en `recibos/tmp/` entre la captura y el fin del OCR.
abstract interface class ReceiptImageStore {
  /// Mueve la imagen de [sourcePath] (la cámara o la galería la dejan en la
  /// caché) a la carpeta temporal privada y devuelve su nueva ruta. Lanza
  /// [ReceiptImageException]; el archivo de origen se borra igual.
  Future<String> stage(String sourcePath, {required String receiptId});

  /// Borra la imagen temporal del recibo [receiptId], si existe.
  Future<void> discardStaged(String receiptId);

  /// Cifra la imagen temporal [stagedPath] y devuelve la ruta relativa del
  /// archivo cifrado (`recibos/<id>.enc`). El temporal se borra siempre,
  /// también si falla. Lanza [ReceiptImageException].
  Future<String> encryptAndStore(
    String stagedPath, {
    required String receiptId,
  });

  /// Descifra en memoria la imagen [relativePath] del recibo [receiptId].
  /// Nunca lanza: un error es [ReceiptImageUnreadable].
  Future<ReceiptImage> read(String? relativePath, {required String receiptId});

  /// Borra la imagen cifrada [relativePath]. No lanza.
  Future<void> delete(String? relativePath);

  /// Borra las imágenes temporales y las cifradas que no están en
  /// [keepPaths], salvo las de los recibos [keepReceiptIds] (en curso).
  Future<void> cleanUp({
    required Set<String> keepPaths,
    required Set<String> keepReceiptIds,
  });
}
