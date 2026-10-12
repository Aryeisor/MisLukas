import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'movement_entry_method.dart';

final newMovementViewModelProvider =
    NotifierProvider.autoDispose<NewMovementViewModel, MovementEntryMethod>(
      NewMovementViewModel.new,
    );

/// Método de registro elegido. La foto viene seleccionada por defecto (§5.2).
class NewMovementViewModel extends Notifier<MovementEntryMethod> {
  @override
  MovementEntryMethod build() => MovementEntryMethod.photo;

  void select(MovementEntryMethod method) => state = method;
}
