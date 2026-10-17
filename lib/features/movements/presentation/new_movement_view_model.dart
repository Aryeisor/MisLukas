import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/movement.dart';
import 'movement_entry_method.dart';

/// Lo elegido en Nuevo movimiento: el tipo (Gasto | Ingreso) y, para un gasto,
/// el método de registro.
class NewMovementSelection {
  const NewMovementSelection({
    this.type = MovementType.expense,
    this.method = MovementEntryMethod.photo,
  });

  final MovementType type;
  final MovementEntryMethod method;

  bool get isIncome => type == MovementType.income;

  @override
  bool operator ==(Object other) =>
      other is NewMovementSelection &&
      other.type == type &&
      other.method == method;

  @override
  int get hashCode => Object.hash(type, method);
}

/// Recibe el tipo inicial: la ruta puede abrir la pantalla con Ingreso
/// (`?type=income`).
final newMovementViewModelProvider = NotifierProvider.autoDispose
    .family<NewMovementViewModel, NewMovementSelection, MovementType>(
      NewMovementViewModel.new,
    );

/// Tipo y método elegidos. Gasto y foto vienen seleccionados por defecto
/// (§5.2).
class NewMovementViewModel extends Notifier<NewMovementSelection> {
  NewMovementViewModel(this.initialType);

  final MovementType initialType;

  @override
  NewMovementSelection build() => NewMovementSelection(type: initialType);

  void selectType(MovementType type) =>
      state = NewMovementSelection(type: type, method: state.method);

  void select(MovementEntryMethod method) =>
      state = NewMovementSelection(type: state.type, method: method);
}
