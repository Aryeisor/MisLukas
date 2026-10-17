/// Usuario autenticado. Dart puro: solo los datos que la app necesita.
class AuthUser {
  const AuthUser({required this.id, required this.email, this.name = ''});

  /// Identificador del usuario en Supabase Auth.
  final String id;
  final String email;

  /// Nombre dado en el registro; vacío si no existe.
  final String name;

  /// Primera palabra del nombre, para el saludo: "Camila Rodríguez" → "Camila".
  String get firstName {
    final words = name.trim().split(RegExp(r'\s+'));
    return words.first;
  }

  @override
  bool operator ==(Object other) =>
      other is AuthUser &&
      other.id == id &&
      other.email == email &&
      other.name == name;

  @override
  int get hashCode => Object.hash(id, email, name);

  // Sin correo ni nombre: el objeto puede terminar en un log.
  @override
  String toString() => 'AuthUser($id)';
}
