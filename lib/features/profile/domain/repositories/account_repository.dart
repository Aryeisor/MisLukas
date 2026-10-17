/// Eliminación de la cuenta en el servidor (RF-48, docs/08 §8.9.4). Dart puro.
///
/// Los métodos lanzan solo [AccountDeletionException].
abstract interface class AccountRepository {
  /// Borra los archivos del usuario en Storage (fotos de recibos
  /// respaldadas). Se puede repetir: si ya no quedan, no hace nada.
  Future<void> deleteStoredFiles();

  /// Elimina el usuario y todos sus datos del servidor. Exige que la
  /// contraseña se haya verificado hace poco y que ya no queden archivos.
  Future<void> deleteAccount();
}

/// Por qué no se pudo eliminar la cuenta.
enum AccountDeletionFailure {
  /// Pasó demasiado tiempo desde que se verificó la contraseña.
  reauthenticationRequired,

  /// Sin conexión o el servidor no respondió.
  network,

  /// Cualquier otro error.
  unknown,
}

class AccountDeletionException implements Exception {
  const AccountDeletionException(this.failure);

  final AccountDeletionFailure failure;

  @override
  String toString() => 'AccountDeletionException(${failure.name})';
}
