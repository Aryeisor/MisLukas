import '../../../budgets/domain/entities/default_categories.dart';
import 'recognized_receipt.dart';

/// Qué tan completa fue la lectura del recibo.
enum ReceiptScanStatus {
  /// Se encontró el total.
  complete,

  /// Se leyó texto, pero no el total: el usuario lo escribe.
  partial,

  /// No se leyó nada útil (imagen ilegible o error al leer).
  empty,
}

/// Lo que la app sugiere a partir del recibo. Es solo una sugerencia: el
/// usuario corrige todo antes de guardar (RF-17).
///
/// Del texto reconocido solo se conservan estos datos; el resto se descarta
/// (docs/08 §8.9.3).
class ReceiptSuggestion {
  const ReceiptSuggestion({
    required this.status,
    required this.date,
    this.total,
    this.merchant,
    this.category,
    this.totalBox,
  });

  /// Lectura sin resultado: sin total, comercio ni categoría, con fecha [today].
  const ReceiptSuggestion.empty(DateTime today)
    : this(status: ReceiptScanStatus.empty, date: today);

  final ReceiptScanStatus status;

  /// Total en pesos; null si no se encontró.
  final int? total;

  /// Nombre del comercio; null si no se encontró.
  final String? merchant;

  /// Día de la compra. Nunca es futuro: si no se reconoció, es hoy.
  final DateTime date;

  /// Categoría sugerida por el comercio o por palabras del recibo (RF-16).
  final DefaultCategory? category;

  /// Zona de la imagen donde está el total ("Área detectada").
  final ReceiptBox? totalBox;
}
