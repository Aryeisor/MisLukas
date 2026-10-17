import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/widgets/widgets.dart';
import 'package:mislukas/features/auth/domain/auth_failure.dart';
import 'package:mislukas/features/auth/presentation/auth_messages.dart';
import 'package:mislukas/features/auth/presentation/login_screen.dart';
import 'package:mislukas/features/auth/presentation/verify_email_screen.dart';

import '../../../helpers/fake_auth_repository.dart';
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
    // El repositorio falso responde en el siguiente ciclo del reloj simulado.
    await tester.pump(Duration.zero);
    await tester.pump();
  }

  const networkMessage =
      'Sin conexión a internet. Revisa tu conexión e intenta de nuevo.';

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

    testWidgets('credenciales incorrectas: mensaje genérico y espera de 1 s', (
      tester,
    ) async {
      final auth = FakeAuthRepository()
        ..failNext(AuthFailure.invalidCredentials);
      await pumpScreen(tester, const LoginScreen(), auth: auth);
      await fillAndSubmit(tester, 'camila@ejemplo.com');

      expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
      expect(find.text('Intenta de nuevo en 1 s'), findsOneWidget);
      expect(isEnabled(tester), isFalse);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Intenta de nuevo en 1 s'), findsNothing);
      expect(isEnabled(tester), isTrue);
    });

    testWidgets('demasiados intentos (429) muestra el bloqueo', (tester) async {
      final auth = FakeAuthRepository()..failNext(AuthFailure.rateLimited);
      await pumpScreen(tester, const LoginScreen(), auth: auth);
      await fillAndSubmit(tester, 'camila@ejemplo.com');

      expect(
        find.text('Demasiados intentos. Espera unos minutos e intenta de nuevo.'),
        findsOneWidget,
      );
      expect(isEnabled(tester), isFalse);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('sin conexión muestra el aviso y permite reintentar', (
      tester,
    ) async {
      final auth = FakeAuthRepository()..failNext(AuthFailure.network);
      await pumpScreen(tester, const LoginScreen(), auth: auth);
      await fillAndSubmit(tester, 'camila@ejemplo.com');

      expect(find.text(networkMessage), findsOneWidget);
      expect(isEnabled(tester), isTrue);
    });

    testWidgets('correo sin verificar ofrece verificarlo', (tester) async {
      final auth = FakeAuthRepository()
        ..failNext(AuthFailure.emailNotConfirmed);
      await pumpScreen(tester, const LoginScreen(), auth: auth);
      await fillAndSubmit(tester, 'camila@ejemplo.com');

      expect(find.text('Verificar correo'), findsOneWidget);
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

    Future<void> fillRegisterForm(
      WidgetTester tester, {
      String password = 'Lukas#Ahorro26',
    }) async {
      await tester.enterText(input('Nombre'), 'Camila');
      await tester.enterText(input('Correo electrónico'), 'camila@ejemplo.com');
      await tester.enterText(input('Contraseña'), password);
      await tester.enterText(input('Confirmar contraseña'), password);
      await tester.pump();
    }

    Future<void> acceptTerms(WidgetTester tester) async {
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
    }

    testWidgets('la casilla de datos personales es obligatoria', (
      tester,
    ) async {
      await openRegister(tester);
      await fillRegisterForm(tester);
      expect(canCreate(tester), isFalse);

      await acceptTerms(tester);
      expect(canCreate(tester), isTrue);
    });

    testWidgets('rechaza una contraseña común aunque cumpla los requisitos', (
      tester,
    ) async {
      await openRegister(tester);
      await fillRegisterForm(tester, password: 'Password1!');
      await acceptTerms(tester);

      expect(find.text(commonPasswordMessage), findsOneWidget);
      expect(canCreate(tester), isFalse);
    });

    testWidgets('crear la cuenta abre "Verifica tu correo"', (tester) async {
      final auth = FakeAuthRepository();
      await pumpApp(tester, auth: auth);
      await tester.tap(find.text('Registrarse'));
      await tester.pumpAndSettle();

      await fillRegisterForm(tester);
      await acceptTerms(tester);
      await tester.ensureVisible(createButton());
      await tester.tap(createButton());
      await tester.pumpAndSettle();

      expect(auth.calls, ['signUp']);
      expect(find.byType(VerifyEmailScreen), findsOneWidget);
      expect(find.text('Verifica tu correo'), findsOneWidget);
      // El correo no se muestra en pantalla.
      expect(find.textContaining('camila@ejemplo.com'), findsNothing);
    });

    testWidgets('un error del servidor se muestra en un banner', (tester) async {
      final auth = FakeAuthRepository()..failNext(AuthFailure.network);
      await pumpScreen(tester, const LoginScreen(), auth: auth);
      await tester.tap(find.text('Registrarse'));
      await tester.pumpAndSettle();

      await fillRegisterForm(tester);
      await acceptTerms(tester);
      await tester.ensureVisible(createButton());
      await tester.tap(createButton());
      await tester.pumpAndSettle();

      expect(find.text(networkMessage), findsOneWidget);
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
