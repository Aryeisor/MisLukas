import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/database/app_database.dart';
import 'package:mislukas/features/budgets/data/drift_notification_settings_repository.dart';
import 'package:mislukas/features/budgets/domain/repositories/notification_services.dart';
import 'package:mislukas/features/profile/presentation/widgets/notification_settings_tile.dart';

import '../../../helpers/fake_device_signals.dart';
import '../../../helpers/pump_screen.dart';
import '../../../helpers/test_database.dart';
import '../../../helpers/test_session.dart';

/// Interruptor "Notificaciones de presupuesto" del Perfil.
void main() {
  Future<FakeNotificationPermission> pumpTile(
    WidgetTester tester,
    AppDatabase db, {
    required NotificationPermissionStatus current,
    NotificationPermissionStatus onRequest =
        NotificationPermissionStatus.granted,
  }) async {
    final permission = FakeNotificationPermission(
      current: current,
      onRequest: onRequest,
    );
    await pumpScreen(
      tester,
      const Scaffold(body: NotificationSettingsTile()),
      database: db,
      session: TestSession(notificationPermission: permission),
    );
    await tester.pumpAndSettle();
    return permission;
  }

  bool switchValue(WidgetTester tester) =>
      tester.widget<Switch>(find.byType(Switch)).value;

  testWidgetsWithDatabase('activadas con permiso; al apagarlas se guarda', (
    tester,
    db,
  ) async {
    await pumpTile(tester, db, current: NotificationPermissionStatus.granted);
    expect(find.text('Notificaciones de presupuesto'), findsOneWidget);
    expect(find.text('Te avisamos al 75% y al 100%'), findsOneWidget);
    expect(switchValue(tester), isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(
      find.text('Desactivadas. Las alertas se ven en Inicio'),
      findsOneWidget,
    );
    expect(switchValue(tester), isFalse);
    expect(
      await pumpUntilDone(
        tester,
        DriftNotificationSettingsRepository(db).isEnabled(),
      ),
      isFalse,
    );
  });

  testWidgetsWithDatabase('sin permiso, activarlas lo pide', (
    tester,
    db,
  ) async {
    final permission = await pumpTile(
      tester,
      db,
      current: NotificationPermissionStatus.denied,
    );
    expect(find.text('Permite las notificaciones del celular'), findsOneWidget);
    expect(switchValue(tester), isFalse);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(permission.requests, 1);
    expect(find.text('Te avisamos al 75% y al 100%'), findsOneWidget);
    expect(switchValue(tester), isTrue);
  });

  testWidgetsWithDatabase('negado permanente ofrece abrir Ajustes', (
    tester,
    db,
  ) async {
    final permission = await pumpTile(
      tester,
      db,
      current: NotificationPermissionStatus.permanentlyDenied,
    );
    expect(
      find.text('Desactivadas en los ajustes del celular'),
      findsOneWidget,
    );

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(permission.requests, 0);
    expect(find.text('Las notificaciones están desactivadas'), findsOneWidget);
    await tester.tap(find.text('Abrir Ajustes'));
    await tester.pumpAndSettle();
    expect(permission.settingsOpened, 1);
  });
}
