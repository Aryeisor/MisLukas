import '../entities/auth_user.dart';

/// Autenticación del usuario (docs/06 §6.7.2).
///
/// Todos los métodos lanzan solo `AuthFailureException`.
abstract interface class AuthRepository {
  /// Usuario con sesión, o null. La sesión guardada se conoce sin red.
  AuthUser? get currentUser;

  /// Emite el usuario cada vez que cambia la sesión: null al cerrarla.
  /// Un fallo de red al renovar el token no cierra la sesión.
  Stream<AuthUser?> authStateChanges();

  /// Inicia sesión con correo y contraseña (RF-05).
  Future<void> signIn({required String email, required String password});

  /// Crea la cuenta y envía el código de verificación al correo (RF-01, RF-04).
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  });

  /// Verifica el código del registro. Si es correcto, inicia la sesión.
  Future<void> verifySignUpCode({required String email, required String code});

  /// Reenvía el código del registro.
  Future<void> resendSignUpCode({required String email});

  /// Envía el código de recuperación, exista o no la cuenta (RF-08, RF-09).
  Future<void> sendPasswordRecovery({required String email});

  /// Verifica el código de recuperación. Si es correcto, crea una sesión
  /// temporal para cambiar la contraseña.
  Future<void> verifyRecoveryCode({required String email, required String code});

  /// Cambia la contraseña y cierra la sesión en todos los dispositivos,
  /// incluido este (RF-10).
  Future<void> updatePassword({required String newPassword});

  /// Cierra la sesión en este dispositivo.
  Future<void> signOut();
}
