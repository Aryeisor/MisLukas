/// Validaciones de formularios (RF-02, docs/08 §8.2.4 y §8.6 y regla de montos
/// de CLAUDE.md). Funciones puras: no dependen de Flutter.
library;

import 'common_passwords.dart';

final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Largo máximo de un correo (RFC 5321).
const int emailMaxLength = 254;

/// Formato básico de correo: texto@dominio.ext, sin espacios.
bool isValidEmail(String email) {
  final trimmed = email.trim();
  return trimmed.length <= emailMaxLength && _emailPattern.hasMatch(trimmed);
}

/// Correo sin espacios y en minúscula.
String normalizeEmail(String email) => email.trim().toLowerCase();

/// Largo máximo del nombre en el registro (docs/08 §8.6).
const int nameMaxLength = 60;

/// El nombre tiene texto y no supera [nameMaxLength].
bool isValidName(String name) {
  final trimmed = name.trim();
  return trimmed.isNotEmpty && trimmed.length <= nameMaxLength;
}

/// Un monto es válido si existe y es mayor que cero.
bool isValidAmount(int? amount) => amount != null && amount > 0;

/// Mínimo de caracteres de una contraseña.
const int passwordMinLength = 8;

/// Máximo de caracteres de una contraseña: bcrypt solo usa los primeros 72
/// bytes.
const int passwordMaxLength = 72;

/// La contraseña está en la lista local de contraseñas comunes
/// (docs/08 §8.2.4). No distingue mayúsculas.
bool isCommonPassword(String password) =>
    commonPasswords.contains(password.toLowerCase());

/// La contraseña cumple los requisitos, no es común y no es demasiado larga.
bool isAcceptablePassword(String password) =>
    PasswordRequirements.check(password).allMet &&
    password.length <= passwordMaxLength &&
    !isCommonPassword(password);

/// Dígitos del código de verificación enviado al correo.
const int otpLength = 6;

final RegExp _otpPattern = RegExp('^\\d{$otpLength}\$');

/// El código tiene exactamente [otpLength] dígitos.
bool isValidOtp(String code) => _otpPattern.hasMatch(code);

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
