import '../../../../core/sync/sync_status.dart';

/// Tipo de un movimiento o de una categoría.
enum MovementType { expense, income }

/// Cómo se registró el movimiento.
enum MovementOrigin { photo, manual }

/// Cuenta por defecto, reservada para manejar varias cuentas en el futuro.
const String defaultAccount = 'principal';

/// Gasto o ingreso (docs/06 §6.4.1). Inmutable, con igualdad por valor.
class Movement {
  const Movement({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.categoryId,
    required this.description,
    this.note,
    required this.origin,
    this.account = defaultAccount,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncStatus = SyncStatus.pending,
  });

  final String id;
  final MovementType type;

  /// Monto en pesos, siempre mayor que cero. El signo lo da [type].
  final int amount;

  /// Día del movimiento, sin hora.
  final DateTime date;
  final String categoryId;
  final String description;
  final String? note;
  final MovementOrigin origin;
  final String account;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Momento del borrado lógico; null si no está eliminado.
  final DateTime? deletedAt;
  final SyncStatus syncStatus;

  bool get isIncome => type == MovementType.income;
  bool get isDeleted => deletedAt != null;

  Movement copyWith({
    MovementType? type,
    int? amount,
    DateTime? date,
    String? categoryId,
    String? description,
    String? Function()? note,
    DateTime? updatedAt,
    DateTime? Function()? deletedAt,
    SyncStatus? syncStatus,
  }) {
    return Movement(
      id: id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      categoryId: categoryId ?? this.categoryId,
      description: description ?? this.description,
      note: note != null ? note() : this.note,
      origin: origin,
      account: account,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt != null ? deletedAt() : this.deletedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Movement &&
      other.id == id &&
      other.type == type &&
      other.amount == amount &&
      other.date == date &&
      other.categoryId == categoryId &&
      other.description == description &&
      other.note == note &&
      other.origin == origin &&
      other.account == account &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.deletedAt == deletedAt &&
      other.syncStatus == syncStatus;

  @override
  int get hashCode => Object.hash(
    id,
    type,
    amount,
    date,
    categoryId,
    description,
    note,
    origin,
    account,
    createdAt,
    updatedAt,
    deletedAt,
    syncStatus,
  );

  // Sin monto ni textos del usuario: el objeto puede terminar en un log (8.8.5).
  @override
  String toString() => 'Movement($id, ${type.name}, ${syncStatus.name})';
}
