/// Errores de validación de los casos de uso. Dart puro.
///
/// Los mensajes para el usuario los decide la presentación a partir de
/// [DomainError]; la excepción no incluye montos ni textos del usuario.
enum DomainError {
  /// El monto está vacío, es cero o negativo (RF-20).
  invalidAmount,

  /// La categoría no existe o fue eliminada.
  categoryNotFound,

  /// La categoría no admite la operación (por ejemplo, presupuesto de ingresos).
  invalidCategory,

  /// El movimiento no existe o fue eliminado.
  movementNotFound,

  /// La descripción o la nota superan la longitud máxima (docs/08 §8.6).
  textTooLong,

  /// La fecha del movimiento es posterior a hoy.
  futureDate,

  /// El presupuesto no existe o ya fue quitado.
  budgetNotFound,
}

class DomainException implements Exception {
  const DomainException(this.error);

  final DomainError error;

  @override
  String toString() => 'DomainException(${error.name})';
}
