/// Errores de autenticación. Dart puro.
///
/// Los mensajes para el usuario los decide la presentación a partir de
/// [AuthFailure]; la excepción no incluye correos, tokens ni detalles del
/// servidor.
enum AuthFailure {
  /// Correo o contraseña incorrectos. Genérico: no dice cuál (RF-06).
  invalidCredentials,

  /// El correo de la cuenta aún no se verificó (RF-04).
  emailNotConfirmed,

  /// El código de verificación es incorrecto o venció.
  invalidCode,

  /// El servidor rechazó la contraseña por no cumplir la política.
  weakPassword,

  /// La contraseña nueva es igual a la anterior.
  samePassword,

  /// Demasiadas solicitudes (429 o límite de intentos, RF-07).
  rateLimited,

  /// Sin conexión o el servidor no respondió.
  network,

  /// Cualquier otro error.
  unknown,
}

class AuthFailureException implements Exception {
  const AuthFailureException(this.failure);

  final AuthFailure failure;

  @override
  String toString() => 'AuthFailureException(${failure.name})';
}
