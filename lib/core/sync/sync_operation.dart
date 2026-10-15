/// Operación registrada en la cola de sincronización (docs/06 §6.6.2).
enum SyncOperation {
  create('crear'),
  update('actualizar'),
  delete('eliminar');

  const SyncOperation(this.sqlValue);

  /// Valor guardado en la columna `operacion`.
  final String sqlValue;
}
