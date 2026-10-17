import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/widgets/widgets.dart';
import 'package:mislukas/features/auth/presentation/auth_messages.dart';
import 'package:mislukas/features/auth/presentation/recover_password_screen.dart';
import 'package:mislukas/features/auth/presentation/verify_email_screen.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/pump_screen.dart';

void main() {
  Finder input(String label) => find.descendant(
    of: find.ancestor(
      of: find.text(label.toUpperCase()),
      matching: find.byType(AppTextField),
    ),
    matching: find.byType(TextField),
  );

  Finder codeInput() => find.descendant(
    of: find.byType(AppCodeField),
    matching: find.byType(TextField),
  );

  Future<void> tapPrimary(WidgetTester tester, String label) async {
    final button = find.widgetWithText(AppPrimaryButton, label);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump(Duration.zero);
    await tester.pump();
  }

  group('Recuperar contraseña', () {
    testWidgets('recorre los 3 pasos y confirma el cierre de sesiones', (
      tester,
    ) async {
      final auth = FakeAuthRepository();
      await pumpScreen(tester, const RecoverPasswordScreen(), auth: auth);
      expect(find.text('Paso 1 de 3'), findsOneWidget);

      await tester.enterText(input('Correo electrónico'), 'camila@ejemplo.com');
      await tester.pump();
      await tapPrimary(tester, 'Enviar código');

      expect(find.text('Paso 2 de 3'), findsOneWidget);
      expect(find.text(recoverySentMessage), findsOneWidget);
      expect(find.text('Reenviar código en 60 s'), findsOneWidget);

      await tester.enterText(codeInput(), '123456');
      await tester.pump();
      await tapPrimary(tester, 'Verificar');

      expect(find.text('Paso 3 de 3'), findsOneWidget);
      await tester.enterText(input('Nueva contraseña'), 'Lukas#Ahorro26');
      await tester.enterText(input('Confirmar contraseña'), 'Lukas#Ahorro26');
      await tester.pump();
      expect(find.byType(AppPasswordStrength), findsOneWidget);
      await tapPrimary(tester, 'Guardar contraseña');

      expect(find.text('Contraseña actualizada'), findsOneWidget);
      expect(
        find.textContaining('cerramos tu sesión en todos tus dispositivos'),
        findsOneWidget,
      );
      expect(auth.calls.last, 'updatePassword');
    });

    testWidgets('sin overflow en 320 x 640 con texto al 130%', (tester) async {
      useSmallScreen(tester);
      await pumpScreen(
        tester,
        const RecoverPasswordScreen(),
        auth: FakeAuthRepository(),
      );
      await expectNoOverflowWhileScrolling(tester);
    });
  });

  group('Verifica tu correo', () {
    testWidgets('verifica el código e informa la cuenta creada', (
      tester,
    ) async {
      final auth = FakeAuthRepository();
      await pumpScreen(
        tester,
        const VerifyEmailScreen(email: 'camila@ejemplo.com'),
        auth: auth,
      );

      expect(find.text('Reenviar código en 60 s'), findsOneWidget);
      await tester.enterText(codeInput(), '123456');
      await tester.pump();
      await tapPrimary(tester, 'Verificar');

      expect(auth.calls, ['verifySignUpCode']);
      expect(find.text('Cuenta creada'), findsOneWidget);
      // Cierra el snackbar y la cuenta regresiva antes de terminar.
      await tester.pump(const Duration(seconds: 61));
    });

    testWidgets('sin overflow en 320 x 640 con texto al 130%', (tester) async {
      useSmallScreen(tester);
      await pumpScreen(
        tester,
        const VerifyEmailScreen(email: 'camila@ejemplo.com'),
        auth: FakeAuthRepository(),
      );
      await expectNoOverflowWhileScrolling(tester);
    });
  });
}
