/// Método con el que el usuario registra un gasto.
enum MovementEntryMethod {
  photo('Foto del recibo'),
  manual('Registro manual');

  const MovementEntryMethod(this.label);

  /// Nombre visible para el usuario.
  final String label;

  /// Convierte el parámetro de la ruta; si no es válido, usa [manual].
  static MovementEntryMethod fromName(String? name) {
    return MovementEntryMethod.values.firstWhere(
      (method) => method.name == name,
      orElse: () => MovementEntryMethod.manual,
    );
  }
}
