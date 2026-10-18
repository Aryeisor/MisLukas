import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../domain/entities/recognized_receipt.dart';
import '../../domain/repositories/receipt_text_reader.dart';

/// OCR de Google ML Kit con el modelo del alfabeto latino incluido en la app:
/// corre en el dispositivo, sin internet (docs/07 §7.3). La imagen no sale
/// del celular.
class MlKitReceiptTextReader implements ReceiptTextReader {
  MlKitReceiptTextReader();

  TextRecognizer? _recognizer;

  @override
  Future<RecognizedReceipt> read(String imagePath) async {
    final recognizer = _recognizer ??= TextRecognizer(
      script: TextRecognitionScript.latin,
    );
    final result = await recognizer.processImage(
      InputImage.fromFilePath(imagePath),
    );
    return RecognizedReceipt([
      for (final block in result.blocks)
        for (final line in block.lines)
          RecognizedLine(
            line.text,
            box: ReceiptBox(
              left: line.boundingBox.left,
              top: line.boundingBox.top,
              right: line.boundingBox.right,
              bottom: line.boundingBox.bottom,
            ),
          ),
    ]);
  }

  /// Libera el modelo.
  Future<void> close() async {
    final recognizer = _recognizer;
    _recognizer = null;
    await recognizer?.close();
  }
}
