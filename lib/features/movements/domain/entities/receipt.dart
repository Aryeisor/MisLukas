/// Datos del recibo de un movimiento registrado por foto (docs/06 §6.4.1).
/// Inmutable, con igualdad por valor.
class Receipt {
  const Receipt({
    required this.id,
    required this.movementId,
    this.localPath,
    this.detectedTotal,
    this.detectedMerchant,
  });

  final String id;
  final String movementId;

  /// Ubicación de la imagen en el almacenamiento interno de la app; null si
  /// el recibo llegó del servidor y la imagen no está en este dispositivo.
  final String? localPath;

  /// Total leído por el OCR, en pesos; null si no se detectó.
  final int? detectedTotal;

  /// Comercio leído por el OCR; null si no se detectó.
  final String? detectedMerchant;

  @override
  bool operator ==(Object other) =>
      other is Receipt &&
      other.id == id &&
      other.movementId == movementId &&
      other.localPath == localPath &&
      other.detectedTotal == detectedTotal &&
      other.detectedMerchant == detectedMerchant;

  @override
  int get hashCode =>
      Object.hash(id, movementId, localPath, detectedTotal, detectedMerchant);

  @override
  String toString() => 'Receipt($id, movement: $movementId)';
}
