import '../domain/auth_failure.dart';

// Mensajes de autenticación para el usuario. Son genéricos: no revelan si un
// correo tiene cuenta (RF-06, RF-09) ni incluyen correos o detalles del
// servidor (docs/08 §8.8.5).

/// Credenciales incorrectas (RF-06).
const String invalidCredentialsMessage = 'Correo o contraseña incorrectos.';

/// Respuesta de la recuperación, exista o no la cuenta (RF-09).
const String recoverySentMessage =
    'Si el correo está registrado, te enviaremos un código de verificación.';

/// Contraseña de la lista local de contraseñas comunes (docs/08 §8.2.4).
const String commonPasswordMessage =
    'Esta contraseña es muy común. Elige otra más difícil de adivinar.';

/// Contraseña de más de 72 caracteres.
const String passwordTooLongMessage =
    'La contraseña no puede tener más de 72 caracteres.';

/// Mensaje para [failure].
String authMessageFor(AuthFailure failure) {
  return switch (failure) {
    AuthFailure.invalidCredentials => invalidCredentialsMessage,
    AuthFailure.emailNotConfirmed =>
      'Aún no verificas tu correo. Ingresa el código que te enviamos.',
    AuthFailure.invalidCode =>
      'El código no es válido o ya venció. Revísalo o pide uno nuevo.',
    AuthFailure.weakPassword =>
      'La contraseña no cumple los requisitos de seguridad. Elige otra.',
    AuthFailure.samePassword =>
      'La nueva contraseña debe ser distinta de la anterior.',
    AuthFailure.rateLimited =>
      'Demasiados intentos. Espera unos minutos e intenta de nuevo.',
    AuthFailure.network =>
      'Sin conexión a internet. Revisa tu conexión e intenta de nuevo.',
    AuthFailure.unknown => 'Algo salió mal. Intenta de nuevo en un momento.',
  };
}
