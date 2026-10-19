import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/database/app_database.dart';
import 'package:mislukas/core/security/device_authenticator.dart';
import 'package:mislukas/core/widgets/widgets.dart';
import 'package:mislukas/features/auth/domain/auth_failure.dart';
import 'package:mislukas/features/auth/presentation/app_lock/app_lock_controller.dart';
import 'package:mislukas/features/profile/presentation/app_lock/enable_app_lock_screen.dart';
import 'package:mislukas/features/profile/presentation/app_lock/enable_app_lock_view_model.dart';
import 'package:mislukas/features/profile/presentation/profile_screen.dart';
import 'package:mislukas/features/profile/presentation/widgets/app_lock_settings_tile.dart';

import '../../../helpers/fake_app_lock.dart';
import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/pump_screen.dart';
import '../../../helpers/test_database.dart';
import '../../../helpers/test_session.dart';

void main() {
  Finder tile() => find.byType(AppLockSettingsTile);

  AppSwitchTile switchTile(WidgetTester tester) => tester.widget<AppSwitchTile>(
    find.descendant(of: tile(), matching: find.byType(AppSwitchTile)),
  );

  /// Inicia sesión y abre el Perfil hasta la fila del bloqueo.
  Future<(TestSession, FakeAuthRepository)> openProfile(
    WidgetTester tester,
    AppDatabase db, {
    bool enabled = false,
    bool hasLock = true,
  }) async {
    final auth = FakeAuthRepository();
    final session = TestSession(
      appLockStore: MemoryAppLockStore(enabled: enabled),
      authenticator: FakeDeviceAuthenticator(hasLock: hasLock),
    );
    await pumpApp(tester, database: db, auth: auth, session: session);
    await loginAsDemoUser(tester);
    await openTab(tester, 'Perfil');
    await tester.scrollUntilVisible(
      tile(),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ProfileScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    return (session, auth);
  }

  Future<void> tapTile(WidgetTester tester) async {
    await tester.tap(tile());
    await tester.pumpAndSettle();
  }

  Future<void> submitPassword(WidgetTester tester, String password) async {
    await tester.enterText(find.byType(TextField), password);
    await tester.pump();
    await tester.tap(find.widgetWithText(AppPrimaryButton, 'Continuar'));
    await tester.pumpAndSettle();
  }

  testWidgetsWithDatabase(
    'activar pide la contraseña y luego el bloqueo del celular',
    (tester, db) async {
      final (session, auth) = await openProfile(tester, db);
      expect(switchTile(tester).value, isFalse);
      expect(find.text(AppLockSettingsTile.offDescription), findsOneWidget);

      await tapTile(tester);
      expect(find.byType(EnableAppLockScreen), findsOneWidget);
      expect(session.authenticator.prompts, isEmpty);

      await submitPassword(tester, 'Clave123*');

      expect(auth.calls, contains('reauthenticate'));
      expect(session.authenticator.prompts, [AppLockController.enableReason]);
      expect(session.appLockStore.enabled, isTrue);
      expect(find.byType(EnableAppLockScreen), findsNothing);
      expect(find.text(EnableAppLockScreen.enabledMessage), findsOneWidget);
      expect(switchTile(tester).value, isTrue);
    },
  );

  testWidgetsWithDatabase('con la contraseña incorrecta no se activa', (
    tester,
    db,
  ) async {
    final (session, auth) = await openProfile(tester, db);
    await tapTile(tester);
    auth.failNext(AuthFailure.invalidCredentials);
    await submitPassword(tester, 'otra');

    expect(find.text(EnableAppLockError.wrongPassword.message), findsOneWidget);
    expect(session.authenticator.prompts, isEmpty);
    expect(session.appLockStore.enabled, isFalse);
  });

  testWidgetsWithDatabase('sin conexión no se puede verificar la contraseña', (
    tester,
    db,
  ) async {
    final (session, auth) = await openProfile(tester, db);
    await tapTile(tester);
    auth.failNext(AuthFailure.network);
    await submitPassword(tester, 'Clave123*');

    expect(find.text(EnableAppLockError.network.message), findsOneWidget);
    expect(session.authenticator.prompts, isEmpty);
  });

  testWidgetsWithDatabase(
    'si cancela el diálogo del sistema, puede reintentar sin la contraseña',
    (tester, db) async {
      final (session, auth) = await openProfile(tester, db);
      await tapTile(tester);
      session.authenticator.nextResults.add(DeviceAuthResult.canceled);
      await submitPassword(tester, 'Clave123*');

      expect(find.text(EnableAppLockError.canceled.message), findsOneWidget);
      expect(session.appLockStore.enabled, isFalse);

      await tester.tap(
        find.widgetWithText(AppPrimaryButton, 'Activar'),
      );
      await tester.pumpAndSettle();
      expect(auth.calls.where((c) => c == 'reauthenticate'), hasLength(1));
      expect(session.authenticator.prompts, hasLength(2));
      expect(session.appLockStore.enabled, isTrue);
    },
  );

  testWidgetsWithDatabase('desactivar pide solo el bloqueo del celular', (
    tester,
    db,
  ) async {
    final (session, auth) = await openProfile(tester, db, enabled: true);
    expect(switchTile(tester).value, isTrue);
    expect(find.text(AppLockSettingsTile.onDescription), findsOneWidget);

    await tapTile(tester);

    expect(auth.calls, isNot(contains('reauthenticate')));
    expect(session.authenticator.prompts, [AppLockController.disableReason]);
    expect(session.appLockStore.enabled, isFalse);
    expect(switchTile(tester).value, isFalse);
  });

  testWidgetsWithDatabase(
    'sin bloqueo de pantalla en el celular, la fila queda desactivada',
    (tester, db) async {
      final (session, _) = await openProfile(tester, db, hasLock: false);
      expect(
        find.text(AppLockSettingsTile.noDeviceLockDescription),
        findsOneWidget,
      );
      expect(switchTile(tester).onChanged, isNull);

      await tapTile(tester);
      expect(find.byType(EnableAppLockScreen), findsNothing);

      // El usuario configura un bloqueo en los Ajustes y vuelve a la app.
      session.authenticator.hasLock = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(switchTile(tester).onChanged, isNotNull);
      expect(find.text(AppLockSettingsTile.offDescription), findsOneWidget);
    },
  );
}
