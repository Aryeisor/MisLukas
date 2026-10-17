import 'domain_exception.dart';

// Mensajes de error para el usuario. Son genéricos: no incluyen montos, textos
// del usuario ni detalles técnicos (docs/08 §8.8.5).

/// La base local no se pudo abrir o leer (por ejemplo, falta la clave).
const String dataLoadErrorMessage =
    'No pudimos abrir tus datos guardados. Cierra y vuelve a abrir la app.';

/// Una escritura falló por una causa distinta a la validación.
const String dataSaveErrorMessage =
    'No pudimos guardar los cambios. Intenta de nuevo.';

/// Mensaje para [error], lanzado al guardar o eliminar.
String userMessageFor(Object error) {
  if (error is! DomainException) return dataSaveErrorMessage;
  return switch (error.error) {
    DomainError.invalidAmount => 'Ingresa un valor mayor que cero.',
    DomainError.categoryNotFound ||
    DomainError.invalidCategory => 'Elige una categoría válida.',
    DomainError.movementNotFound => 'Este movimiento ya no existe.',
    DomainError.textTooLong => 'La nota es demasiado larga.',
    DomainError.futureDate => 'La fecha no puede ser posterior a hoy.',
    DomainError.budgetNotFound => 'Este presupuesto ya no existe.',
  };
}
