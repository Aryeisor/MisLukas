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

  group('autenticación (docs/08 §8.2.4 y §8.6)', () {
    test('normalizeEmail quita espacios y pasa a minúscula', () {
      expect(normalizeEmail('  Camila@Ejemplo.COM '), 'camila@ejemplo.com');
    });

    test('isValidEmail rechaza correos de más de 254 caracteres', () {
      final long = '${'a' * 250}@b.co';
      expect(isValidEmail(long), isFalse);
    });

    test('isValidName exige texto y como máximo 60 caracteres', () {
      expect(isValidName('Camila'), isTrue);
      expect(isValidName('   '), isFalse);
      expect(isValidName('a' * nameMaxLength), isTrue);
      expect(isValidName('a' * (nameMaxLength + 1)), isFalse);
    });

    test('isCommonPassword reconoce contraseñas comunes sin importar mayúsculas',
        () {
      expect(isCommonPassword('Password1!'), isTrue);
      expect(isCommonPassword('COLOMBIA123*'), isTrue);
      expect(isCommonPassword('Lukas#Ahorro26'), isFalse);
    });

    test('isAcceptablePassword: requisitos, no común y máximo 72', () {
      expect(isAcceptablePassword('Lukas#Ahorro26'), isTrue);
      expect(isAcceptablePassword('Password1!'), isFalse);
      expect(isAcceptablePassword('lukas#ahorro26'), isFalse);
      expect(isAcceptablePassword('Aa1*${'x' * 69}'), isFalse);
    });

    test('isValidOtp exige exactamente 6 dígitos', () {
      expect(isValidOtp('123456'), isTrue);
      expect(isValidOtp('12345'), isFalse);
      expect(isValidOtp('1234567'), isFalse);
      expect(isValidOtp('12345a'), isFalse);
    });
  });
}
