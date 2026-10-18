import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mislukas/core/database/app_database.dart';
import 'package:mislukas/core/widgets/widgets.dart';
import 'package:mislukas/features/auth/presentation/login_screen.dart';
import 'package:mislukas/features/auth/presentation/recover_password_screen.dart';
import 'package:mislukas/features/home/presentation/home_screen.dart';
import 'package:mislukas/features/movements/presentation/confirm_movement_screen.dart';
import 'package:mislukas/features/movements/domain/repositories/receipt_capture_services.dart';
import 'package:mislukas/features/movements/presentation/new_movement_screen.dart';
import 'package:mislukas/features/movements/presentation/receipt/receipt_capture_screen.dart';
import 'package:mislukas/features/profile/presentation/profile_screen.dart';
import 'package:mislukas/features/reports/presentation/reports_screen.dart';
import 'package:mislukas/features/simulator/presentation/simulator_screen.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_receipt_services.dart';
import '../../helpers/pump_screen.dart';
import '../../helpers/test_database.dart';

void main() {
  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomNav),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgetsWithDatabase('arranca en /login y desde ahí llega a /home', (
    tester,
    db,
  ) async {
    await pumpApp(tester, database: db);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(AppBottomNav), findsNothing);

    await loginAsDemoUser(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(AppBottomNav), findsOneWidget);
  });

  testWidgetsWithDatabase('con sesión guardada arranca en /home', (
    tester,
    db,
  ) async {
    await pumpApp(
      tester,
      database: db,
      auth: FakeAuthRepository(signedInAs: testUser),
    );
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Hola, Camila 👋'), findsOneWidget);
  });

  testWidgetsWithDatabase(
    'un fallo de red al renovar el token no cierra la sesión',
    (tester, db) async {
      final auth = FakeAuthRepository(signedInAs: testUser);
      await pumpApp(tester, database: db, auth: auth);

      auth.emitStreamError();
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    },
  );

  testWidgetsWithDatabase('si la sesión se revoca vuelve a /login', (
    tester,
    db,
  ) async {
    final auth = FakeAuthRepository(signedInAs: testUser);
    await pumpApp(tester, database: db, auth: auth);
    await tapTab(tester, 'Reportes');

    auth.setSession(null);
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(AppBottomNav), findsNothing);
  });

  testWidgetsWithDatabase('"¿Olvidaste tu contraseña?" abre la recuperación', (
    tester,
    db,
  ) async {
    await pumpApp(tester, database: db);
    await tester.tap(find.text('¿Olvidaste tu contraseña?'));
    await tester.pumpAndSettle();

    expect(find.byType(RecoverPasswordScreen), findsOneWidget);
    expect(find.text('Paso 1 de 3'), findsOneWidget);

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  group('recuperación de contraseña con la app completa', () {
    Finder input(String label) => find.descendant(
      of: find.ancestor(
        of: find.text(label.toUpperCase()),
        matching: find.byType(AppTextField),
      ),
      matching: find.byType(TextField),
    );

    Future<void> tapPrimary(WidgetTester tester, String label) async {
      final button = find.widgetWithText(AppPrimaryButton, label);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    /// Desde /login hasta verificar el código. El repositorio falso emite la
    /// sesión temporal al verificar, como Supabase.
    Future<FakeAuthRepository> verifyRecoveryCode(
      WidgetTester tester,
      AppDatabase db,
    ) async {
      final auth = FakeAuthRepository();
      await pumpApp(tester, database: db, auth: auth);
      await tester.tap(find.text('¿Olvidaste tu contraseña?'));
      await tester.pumpAndSettle();

      await tester.enterText(input('Correo electrónico'), 'camila@ejemplo.com');
      await tester.pump();
      await tapPrimary(tester, 'Enviar código');

      await tester.enterText(
        find.descendant(
          of: find.byType(AppCodeField),
          matching: find.byType(TextField),
        ),
        '123456',
      );
      await tester.pump();
      await tapPrimary(tester, 'Verificar');
      return auth;
    }

    testWidgetsWithDatabase(
      'la sesión temporal no saca al usuario: llega al paso 3',
      (tester, db) async {
        final auth = await verifyRecoveryCode(tester, db);

        expect(auth.currentUser, testUser);
        expect(find.byType(RecoverPasswordScreen), findsOneWidget);
        expect(find.text('Paso 3 de 3'), findsOneWidget);
        expect(find.byType(HomeScreen), findsNothing);
        expect(find.byType(LoginScreen), findsNothing);
        expect(auth.calls, isNot(contains('signOut')));
      },
    );

    testWidgetsWithDatabase(
      'guardar la contraseña cierra sesión en todos lados y vuelve a /login',
      (tester, db) async {
        final auth = await verifyRecoveryCode(tester, db);

        await tester.enterText(input('Nueva contraseña'), 'Lukas#Ahorro26');
        await tester.enterText(input('Confirmar contraseña'), 'Lukas#Ahorro26');
        await tester.pump();
        await tapPrimary(tester, 'Guardar contraseña');

        expect(find.text('Contraseña actualizada'), findsOneWidget);
        expect(auth.calls.last, 'updatePassword');
        expect(auth.currentUser, isNull);

        await tapPrimary(tester, 'Ir a iniciar sesión');
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(HomeScreen), findsNothing);
      },
    );

    testWidgetsWithDatabase(
      'Volver después de verificar cierra la sesión temporal',
      (tester, db) async {
        final auth = await verifyRecoveryCode(tester, db);

        await tester.tap(find.byTooltip('Volver'));
        await tester.pumpAndSettle();

        expect(auth.calls.last, 'signOut');
        expect(auth.currentUser, isNull);
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(HomeScreen), findsNothing);
      },
    );

    testWidgetsWithDatabase(
      'el atrás del sistema después de verificar cierra la sesión temporal',
      (tester, db) async {
        final auth = await verifyRecoveryCode(tester, db);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(auth.calls.last, 'signOut');
        expect(auth.currentUser, isNull);
        expect(find.byType(LoginScreen), findsOneWidget);
      },
    );
  });

  testWidgetsWithDatabase('la barra inferior cambia entre las 4 pestañas', (
    tester,
    db,
  ) async {
    await pumpApp(tester, database: db);
    await loginAsDemoUser(tester);

    await tapTab(tester, 'Reportes');
    expect(find.byType(ReportsScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);

    await tapTab(tester, 'Simular');
    expect(find.byType(SimulatorScreen), findsOneWidget);

    await tapTab(tester, 'Perfil');
    expect(find.byType(ProfileScreen), findsOneWidget);

    await tapTab(tester, 'Inicio');
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgetsWithDatabase('/movements/new se abre sin barra inferior', (
    tester,
    db,
  ) async {
    await pumpApp(tester, database: db);
    await loginAsDemoUser(tester);

    await tester.tap(find.text('Nuevo movimiento'));
    await tester.pumpAndSettle();

    expect(find.byType(NewMovementScreen), findsOneWidget);
    expect(find.byType(AppBottomNav), findsNothing);

    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(AppBottomNav), findsOneWidget);
  });

  testWidgetsWithDatabase(
    'Continuar con foto abre la captura del recibo, sin barra inferior',
    (tester, db) async {
      // Sin permiso todavía: se ve la explicación previa, sin cámara.
      await pumpApp(
        tester,
        database: db,
        overrides: receiptServiceOverrides(
          permission: FakeCameraPermission(
            current: CameraPermissionStatus.denied,
          ),
        ),
      );
      await loginAsDemoUser(tester);

      await tester.tap(find.text('Nuevo movimiento'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(find.byType(ReceiptCaptureScreen), findsOneWidget);
      expect(find.text('Permite el acceso a la cámara'), findsOneWidget);
      expect(find.byType(AppBottomNav), findsNothing);

      // "Ahora no" vuelve a Nuevo movimiento.
      await tester.tap(find.text('Ahora no'));
      await tester.pumpAndSettle();
      expect(find.byType(NewMovementScreen), findsOneWidget);
    },
  );

  testWidgetsWithDatabase(
    'un enlace a la confirmación por foto sin foto abre la captura',
    (tester, db) async {
      await pumpApp(
        tester,
        database: db,
        overrides: receiptServiceOverrides(
          permission: FakeCameraPermission(
            current: CameraPermissionStatus.denied,
          ),
        ),
      );
      await loginAsDemoUser(tester);

      GoRouter.of(tester.element(find.byType(HomeScreen)))
          .go('/movements/confirm?method=photo');
      await tester.pumpAndSettle();

      expect(find.byType(ReceiptCaptureScreen), findsOneWidget);
      expect(find.byType(ConfirmMovementScreen), findsNothing);
    },
  );

  testWidgetsWithDatabase(
    'Continuar con registro manual abre Registra tu gasto',
    (tester, db) async {
      await pumpApp(tester, database: db);
      await loginAsDemoUser(tester);

      await tester.tap(find.text('Nuevo movimiento'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registro manual'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(find.byType(ConfirmMovementScreen), findsOneWidget);
      expect(find.text('Registra tu gasto'), findsOneWidget);
      expect(find.byType(AppBottomNav), findsNothing);
    },
  );

  testWidgetsWithDatabase(
    'tocar un movimiento abre su edición sin barra inferior',
    (tester, db) async {
      await pumpApp(tester, database: db);
      await loginAsDemoUser(tester);

      final tile = find.byType(MovementTile).first;
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(find.byType(ConfirmMovementScreen), findsOneWidget);
      expect(find.text('Editar movimiento'), findsOneWidget);
      expect(find.byType(AppBottomNav), findsNothing);

      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );
}
