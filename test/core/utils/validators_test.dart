import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/utils/validators.dart';

void main() {
  group('isValidEmail', () {
    test('acepta correos con formato válido', () {
      expect(isValidEmail('camila@ejemplo.com'), isTrue);
      expect(isValidEmail('  camila.perez@correo.co  '), isTrue);
    });

    test('rechaza correos sin @, sin dominio o con espacios', () {
      expect(isValidEmail(''), isFalse);
      expect(isValidEmail('camila'), isFalse);
      expect(isValidEmail('camila@'), isFalse);
      expect(isValidEmail('camila@ejemplo'), isFalse);
      expect(isValidEmail('cami la@ejemplo.com'), isFalse);
    });
  });

  group('isValidAmount', () {
    test('solo acepta montos mayores que cero', () {
      expect(isValidAmount(87400), isTrue);
      expect(isValidAmount(1), isTrue);
      expect(isValidAmount(0), isFalse);
      expect(isValidAmount(-5), isFalse);
      expect(isValidAmount(null), isFalse);
    });
  });

  group('PasswordRequirements', () {
    test('contraseña vacía no cumple ningún requisito', () {
      final requirements = PasswordRequirements.check('');
      expect(requirements.metCount, 0);
      expect(requirements.allMet, isFalse);
    });

    test('detecta cada requisito por separado', () {
      expect(PasswordRequirements.check('abcdefgh').minLength, isTrue);
      expect(PasswordRequirements.check('abcdefg').minLength, isFalse);
      expect(PasswordRequirements.check('Ñandú').hasUppercase, isTrue);
      expect(PasswordRequirements.check('abc').hasUppercase, isFalse);
      expect(PasswordRequirements.check('abc1').hasNumber, isTrue);
      expect(PasswordRequirements.check('abc*').hasSymbol, isTrue);
    });

    test('letras con tilde y espacios no cuentan como símbolo', () {
      expect(PasswordRequirements.check('canción ñ').hasSymbol, isFalse);
    });

    test('Clave123* cumple todos los requisitos', () {
      expect(PasswordRequirements.check('Clave123*').allMet, isTrue);
    });
  });

  group('passwordStrength', () {
    test('débil con menos de 3 requisitos', () {
      expect(passwordStrength('abc'), PasswordStrength.weak);
      expect(passwordStrength('abcdefgh1'), PasswordStrength.weak);
    });

    test('media con 3 requisitos', () {
      expect(passwordStrength('Abcdefgh1'), PasswordStrength.medium);
    });

    test('fuerte con los 4 requisitos', () {
      expect(passwordStrength('Clave123*'), PasswordStrength.strong);
    });
  });
}
