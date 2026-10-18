import '../../domain/entities/receipt_suggestion.dart';

/// Foto del recibo ya leída y cifrada, que pasa de la captura a Confirma los
/// datos (en el `extra` de go_router).
class ReceiptCapture {
  const ReceiptCapture({
    required this.receiptId,
    required this.localPath,
    required this.suggestion,
  });

  /// Id del recibo que se va a crear: también nombra su imagen.
  final String receiptId;

  /// Imagen cifrada, relativa al directorio de la app (`recibos/<id>.enc`).
  final String localPath;

  /// Lo que leyó el OCR. Solo el total, el comercio, la fecha, la categoría
  /// y la zona del total: el resto del texto ya se descartó.
  final ReceiptSuggestion suggestion;

  @override
  bool operator ==(Object other) =>
      other is ReceiptCapture && other.receiptId == receiptId;

  @override
  int get hashCode => receiptId.hashCode;
}
