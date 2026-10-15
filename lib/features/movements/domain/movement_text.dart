// Limpieza de los textos de un movimiento (docs/08 §8.6). Dart puro.

/// Largo máximo de la descripción, la nota y el comercio detectado.
const int movementTextMaxLength = 200;

final RegExp _controlCharacters = RegExp(r'\p{Cc}', unicode: true);

/// Quita caracteres de control y espacios al inicio y al final.
String sanitizeMovementText(String text) =>
    text.replaceAll(_controlCharacters, '').trim();

/// Texto leído por el OCR: dato no confiable, se limpia y se recorta al largo
/// máximo. Devuelve null si queda vacío.
String? sanitizeDetectedText(String? text) {
  if (text == null) return null;
  final clean = sanitizeMovementText(text);
  if (clean.isEmpty) return null;
  return clean.length <= movementTextMaxLength
      ? clean
      : clean.substring(0, movementTextMaxLength).trim();
}
