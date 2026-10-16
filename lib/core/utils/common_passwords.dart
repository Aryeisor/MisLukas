/// Contraseñas más comunes, en minúscula, que se rechazan desde el cliente
/// mientras no se active la protección de contraseñas filtradas de Supabase
/// (docs/08 §8.2.4). Incluye variantes que cumplen los requisitos de RF-02
/// (mayúscula, número y símbolo), porque son las que pasarían la validación.
const Set<String> commonPasswords = {
  // Las más usadas en el mundo
  '123456', '123456789', '12345678', 'password', 'qwerty', '12345',
  '1234567', '111111', '123123', '1234567890', '000000', 'abc123',
  'password1', 'iloveyou', 'qwerty123', '1q2w3e4r', 'admin', 'welcome',
  'monkey', 'dragon', 'letmein', 'football', 'sunshine', 'princess',
  // En español y de Colombia
  'contraseña', 'contrasena', 'colombia', 'teamo', 'tequiero', 'hola123',
  'bogota', 'medellin', 'cali', 'millonarios', 'nacional', 'america',
  // Variantes que cumplen mayúscula, número y símbolo
  'password1!', 'password123!', 'password1*', 'password1.', 'p@ssw0rd',
  'p@ssw0rd1', 'p@ssword1', 'passw0rd!', 'qwerty123!', 'qwerty1!',
  'qwerty123*', 'qwerty1*', 'welcome1!', 'welcome123!', 'admin123!',
  'admin123*', 'abc123!', 'abc123*', 'abcd1234!', 'abcd1234*',
  'iloveyou1!', 'letmein1!', 'monkey123!', 'dragon123!', 'sunshine1!',
  'princess1!', 'football1!', 'changeme1!', 'test1234!', 'test123!',
  'hello123!', 'hola1234!', 'hola123*', 'hola123!', 'colombia1!',
  'colombia123!', 'colombia123*', 'colombia2024!', 'colombia2025!',
  'colombia2026!', 'contraseña1!', 'contraseña123!', 'contrasena1!',
  'contrasena123!', 'teamo123!', 'teamo123*', 'tequiero1!', 'bogota123!',
  'medellin123!', 'mislukas1!', 'mislukas123!', 'mislukas123*',
  'clave123!', 'clave123*', 'clave1234!', 'usuario123!', 'usuario1!',
  'america123!', 'nacional123!', 'millonarios1!', 'enero2026!',
  'febrero2026!', 'septiembre2026!', 'octubre2026!', 'diciembre2025!',
  'verano2026!', 'invierno2026!', 'qwer1234!', 'asdf1234!', 'zxcv1234!',
  '1qaz2wsx!', 'q1w2e3r4!', 'a1b2c3d4!', 'aa123456!', 'aa123456*',
};
