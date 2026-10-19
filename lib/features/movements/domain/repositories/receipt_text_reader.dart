import '../entities/recognized_receipt.dart';

/// Reconoce el texto de la imagen en [imagePath], en el dispositivo y sin
/// conexión (docs/07 §7.3, RF-15).
abstract interface class ReceiptTextReader {
  /// Lanza una excepción si la imagen no se puede leer.
  Future<RecognizedReceipt> read(String imagePath);
}
