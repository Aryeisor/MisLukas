/// Validaciones de formularios (RF-02 y regla de montos de CLAUDE.md).
/// Funciones puras: no dependen de Flutter.
library;

final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Formato básico de correo: texto@dominio.ext, sin espacios.
bool isValidEmail(String email) => _emailPattern.hasMatch(email.trim());

/// Un monto es válido si existe y es mayor que cero.
bool isValidAmount(int? amount) => amount != null && amount > 0;

/// Mínimo de caracteres de una contraseña.
const int passwordMinLength = 8;

/// Requisitos de la contraseña (RF-02) y cuáles se cumplen.
class PasswordRequirements {
  const PasswordRequirements({
    required this.minLength,
    required this.hasUppercase,
    required this.hasNumber,
    required this.hasSymbol,
  });

  factory PasswordRequirements.check(String password) {
    return PasswordRequirements(
      minLength: password.length >= passwordMinLength,
      hasUppercase: RegExp(r'\p{Lu}', unicode: true).hasMatch(password),
      hasNumber: RegExp(r'\d').hasMatch(password),
      // Cualquier carácter que no sea letra, número ni espacio.
      hasSymbol: RegExp(r'[^\p{L}\p{N}\s]', unicode: true).hasMatch(password),
    );
  }

  final bool minLength;
  final bool hasUppercase;
  final bool hasNumber;
  final bool hasSymbol;

  int get metCount =>
      [minLength, hasUppercase, hasNumber, hasSymbol].where((met) => met).length;

  bool get allMet => metCount == 4;
}

/// Nivel de fortaleza de una contraseña.
enum PasswordStrength { weak, medium, strong }

/// Fuerte si cumple los 4 requisitos, media con 3 y débil con menos.
PasswordStrength passwordStrength(String password) {
  return switch (PasswordRequirements.check(password).metCount) {
    4 => PasswordStrength.strong,
    3 => PasswordStrength.medium,
    _ => PasswordStrength.weak,
  };
}
