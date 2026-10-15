import '../../../movements/domain/entities/movement.dart';

/// Categoría de movimientos (docs/06 §6.4.1). Inmutable, con igualdad por valor.
class Category {
  const Category({
    required this.id,
    required this.key,
    required this.name,
    required this.type,
    required this.isDefault,
  });

  final String id;

  /// Clave estable de una categoría predeterminada ("mercado"); null en las
  /// personalizadas (futuro).
  final String? key;
  final String name;
  final MovementType type;
  final bool isDefault;

  @override
  bool operator ==(Object other) =>
      other is Category &&
      other.id == id &&
      other.key == key &&
      other.name == name &&
      other.type == type &&
      other.isDefault == isDefault;

  @override
  int get hashCode => Object.hash(id, key, name, type, isDefault);

  @override
  String toString() => 'Category($id, $key)';
}
