import '../../../../core/utils/clock.dart';
import '../entities/receipt_suggestion.dart';
import '../receipt/receipt_parser.dart';
import '../repositories/receipt_text_reader.dart';

/// Lee la foto de un recibo con el OCR del dispositivo y la convierte en una
/// sugerencia (docs/07 §7.3, RF-15, RF-16).
///
/// Nunca falla: si la imagen no se puede leer, devuelve una sugerencia vacía
/// y el usuario sigue de forma manual (RF-18). No registra el error: podría
/// incluir texto del recibo (docs/08 §8.8.5).
class ScanReceipt {
  const ScanReceipt({
    required this._reader,
    required this._clock,
    this._parser = const ReceiptParser(),
  });

  final ReceiptTextReader _reader;
  final Clock _clock;
  final ReceiptParser _parser;

  Future<ReceiptSuggestion> call(String imagePath) async {
    final today = _clock.today();
    try {
      final text = await _reader.read(imagePath);
      return _parser.parse(text, today: today);
    } catch (_) {
      return ReceiptSuggestion.empty(today);
    }
  }
}
