import '../../../budgets/domain/entities/default_categories.dart';
import '../entities/movement.dart';
import 'register_movement.dart';

/// Registra un ingreso (RF-19, RF-50): siempre con la categoría Ingreso,
/// origen manual y sin recibo.
///
/// Usa las mismas validaciones que [RegisterMovement]: monto mayor que cero,
/// largo máximo del texto y fecha no posterior a hoy. Si la descripción queda
/// vacía, se usa "Ingreso".
class RegisterIncome {
  const RegisterIncome(this._register);

  final RegisterMovement _register;

  /// Lanza `DomainException` si los datos no son válidos.
  Future<Movement> call({
    required int? amount,
    String description = '',
    DateTime? date,
  }) {
    return _register(
      amount: amount,
      categoryId: DefaultCategory.ingreso.id,
      origin: MovementOrigin.manual,
      description: description,
      date: date,
    );
  }
}
