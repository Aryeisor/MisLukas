import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/widgets/widgets.dart';
import 'package:mislukas/features/auth/presentation/login_screen.dart';

import '../../../helpers/pump_screen.dart';

void main() {
  Finder field(String label) => find.ancestor(
    of: find.text(label.toUpperCase()),
    matching: find.byType(AppTextField),
  );

  Finder input(String label) =>
      find.descendant(of: field(label), matching: find.byType(TextField));

  Finder loginButton() =>
      find.widgetWithText(AppPrimaryButton, 'Iniciar sesión');

  bool isEnabled(WidgetTester tester) =>
      tester.widget<AppPrimaryButton>(loginButton()).onPressed != null;

  Future<void> fillAndSubmit(WidgetTester tester, String email) async {
    await tester.enterText(input('Correo electrónico'), email);
    await tester.enterText(input('Contraseña'), 'Clave123*');
    await tester.pump();
    await tester.tap(loginButton());
    await tester.pump();
    // Carga simulada de 1 segundo.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  group('Iniciar sesión', () {
    testWidgets('el botón se habilita solo con correo válido y contraseña', (
      tester,
    ) async {
      await pumpScreen(tester, const LoginScreen());
      expect(isEnabled(tester), isFalse);

      await tester.enterText(input('Correo electrónico'), 'camila@');
      await tester.enterText(input('Contraseña'), 'Clave123*');
      await tester.pump();
      expect(isEnabled(tester), isFalse);

      await tester.enterText(input('Correo electrónico'), 'camila@ejemplo.com');
      await tester.pump();
      expect(isEnabled(tester), isTrue);

      await tester.enterText(input('Contraseña'), '');
      await tester.pump();
      expect(isEnabled(tester), isFalse);
    });

    testWidgets('error@demo.com muestra el mensaje genérico', (tester) async {
      await pumpScreen(tester, const LoginScreen());
      await fillAndSubmit(tester, 'error@demo.com');

      expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
      expect(isEnabled(tester), isTrue);
    });

    testWidgets('bloqueado@demo.com muestra el bloqueo y deshabilita el botón', (
      tester,
    ) async {
      await pumpScreen(tester, const LoginScreen());
      await fillAndSubmit(tester, 'bloqueado@demo.com');

      expect(
        find.text('Demasiados intentos. Intenta de nuevo en 15 minutos.'),
        findsOneWidget,
      );
      expect(isEnabled(tester), isFalse);
    });

    testWidgets('Google y Apple están deshabilitados con "Próximamente"', (
      tester,
    ) async {
      await pumpScreen(tester, const LoginScreen());

      expect(find.text('Próximamente'), findsNWidgets(2));
      for (final label in ['Continuar con Google', 'Continuar con Apple']) {
        final button = tester.widget<AppSecondaryButton>(
          find.widgetWithText(AppSecondaryButton, label),
        );
        expect(button.onPressed, isNull);
      }
    });
  });

  group('Registrarse', () {
    Finder createButton() =>
        find.widgetWithText(AppPrimaryButton, 'Crear cuenta');

    bool canCreate(WidgetTester tester) =>
        tester.widget<AppPrimaryButton>(createButton()).onPressed != null;

    Future<void> openRegister(WidgetTester tester) async {
      await pumpScreen(tester, const LoginScreen());
      await tester.tap(find.text('Registrarse'));
      await tester.pumpAndSettle();
    }

    bool requirementMet(WidgetTester tester, String label) {
      final row = find.ancestor(
        of: find.text(label),
        matching: find.byType(Row),
      ).first;
      return find
          .descendant(of: row, matching: find.byIcon(Icons.check_circle))
          .evaluate()
          .isNotEmpty;
    }

    testWidgets('los requisitos aparecen al escribir y se marcan', (
      tester,
    ) async {
      await openRegister(tester);
      expect(find.byType(AppPasswordStrength), findsNothing);

      await tester.enterText(input('Contraseña'), 'abc1');
      await tester.pump();
      expect(find.byType(AppPasswordStrength), findsOneWidget);
      expect(find.text('Débil'), findsOneWidget);
      expect(requirementMet(tester, 'Un número'), isTrue);
      expect(requirementMet(tester, 'Mínimo 8 caracteres'), isFalse);
      expect(requirementMet(tester, 'Una mayúscula'), isFalse);
      expect(requirementMet(tester, 'Un símbolo'), isFalse);

      await tester.enterText(input('Contraseña'), 'Clave123*');
      await tester.pump();
      expect(find.text('Fuerte'), findsOneWidget);
      for (final label in [
        'Mínimo 8 caracteres',
        'Una mayúscula',
        'Un número',
        'Un símbolo',
      ]) {
        expect(requirementMet(tester, label), isTrue, reason: label);
      }
    });

    testWidgets('avisa si las contraseñas no coinciden', (tester) async {
      await openRegister(tester);
      await tester.enterText(input('Contraseña'), 'Clave123*');
      await tester.enterText(input('Confirmar contraseña'), 'Clave123');
      await tester.pump();
      expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
    });

    testWidgets('la casilla de datos personales es obligatoria', (
      tester,
    ) async {
      await openRegister(tester);
      await tester.enterText(input('Nombre'), 'Camila');
      await tester.enterText(input('Correo electrónico'), 'camila@ejemplo.com');
      await tester.enterText(input('Contraseña'), 'Clave123*');
      await tester.enterText(input('Confirmar contraseña'), 'Clave123*');
      await tester.pump();
      expect(canCreate(tester), isFalse);

      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(canCreate(tester), isTrue);

      await tester.ensureVisible(createButton());
      await tester.tap(createButton());
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Verifica tu correo'), findsOneWidget);
      expect(find.textContaining('camila@ejemplo.com'), findsOneWidget);

      await tester.tap(find.text('Ir a iniciar sesión'));
      await tester.pumpAndSettle();
      expect(loginButton(), findsOneWidget);
    });
  });

  group('Pantalla pequeña (320 x 640, texto al 130%)', () {
    testWidgets('inicio de sesión sin overflow', (tester) async {
      useSmallScreen(tester);
      await pumpScreen(tester, const LoginScreen());
      await expectNoOverflowWhileScrolling(tester);
    });

    testWidgets('registro sin overflow, con requisitos visibles', (
      tester,
    ) async {
      useSmallScreen(tester);
      await pumpScreen(tester, const LoginScreen());
      await tester.tap(find.text('Registrarse'));
      await tester.pumpAndSettle();
      await tester.enterText(input('Contraseña'), 'abc');
      await tester.enterText(input('Confirmar contraseña'), 'abcd');
      await tester.pumpAndSettle();
      await expectNoOverflowWhileScrolling(tester);
    });
  });
}
