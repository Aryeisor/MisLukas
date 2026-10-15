/// Estado de sincronización de un registro local (docs/06 §6.6.2). Dart puro.
enum SyncStatus {
  /// Coincide con el servidor.
  synced,

  /// Tiene cambios que aún no se envían.
  pending,

  /// El servidor lo rechazó.
  error,
}
