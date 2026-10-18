/// Texto que el OCR reconoció en la foto de un recibo (docs/07 §7.3). Dart
/// puro: no depende de ML Kit ni de `dart:ui`.
library;

/// Rectángulo de una línea en píxeles de la imagen.
class ReceiptBox {
  const ReceiptBox({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;
  double get centerY => (top + bottom) / 2;

  /// Rectángulo que contiene a este y a [other].
  ReceiptBox union(ReceiptBox other) => ReceiptBox(
    left: left < other.left ? left : other.left,
    top: top < other.top ? top : other.top,
    right: right > other.right ? right : other.right,
    bottom: bottom > other.bottom ? bottom : other.bottom,
  );

  @override
  bool operator ==(Object other) =>
      other is ReceiptBox &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);
}

/// Una línea reconocida, con su ubicación si el OCR la entregó.
class RecognizedLine {
  const RecognizedLine(this.text, {this.box});

  final String text;
  final ReceiptBox? box;
}

/// Todas las líneas reconocidas en la imagen.
class RecognizedReceipt {
  const RecognizedReceipt(this.lines);

  /// Cada línea del [text] es una línea reconocida, sin ubicación (pruebas).
  factory RecognizedReceipt.fromText(String text) => RecognizedReceipt([
    for (final line in text.split('\n')) RecognizedLine(line),
  ]);

  static const RecognizedReceipt empty = RecognizedReceipt([]);

  final List<RecognizedLine> lines;

  /// No hay ningún texto reconocido.
  bool get isBlank => lines.every((line) => line.text.trim().isEmpty);
}
