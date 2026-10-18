import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/database/app_database.dart';
import 'package:mislukas/core/widgets/widgets.dart';
import 'package:mislukas/features/budgets/domain/repositories/notification_services.dart';
import 'package:mislukas/features/budgets/presentation/budgets_screen.dart';

import '../../../helpers/fake_device_signals.dart';
import '../../../helpers/pump_screen.dart';
import '../../../helpers/test_database.dart';
import '../../../helpers/test_session.dart';

/// Explicación previa del permiso de notificaciones (docs/07 §7.9): se ofrece
/// al guardar un presupuesto, una sola vez, y nunca se insiste.
void main() {
  const explanationTitle = 'Te avisamos de tus presupuestos';

  Finder limitInput() => find.descendant(
    of: find.byType(AppAmountField),
    matching: find.byType(TextField),
  );

  Future<void> saveBudget(
    WidgetTester tester,
    String category,
    String amount,
  ) async {
    final card = find.text(category);
    await tester.scrollUntilVisible(
      card,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();
    await tester.enterText(limitInput(), amount);
    await tester.pump();
    await tester.tap(find.widgetWithText(AppPrimaryButton, 'Guardar'));
    await tester.pumpAndSettle();
  }

  Future<FakeNotificationPermission> pumpBudgets(
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
      const BudgetsScreen(),
      database: db,
      session: TestSession(notificationPermission: permission),
    );
    return permission;
  }

  testWidgetsWithDatabase('con el permiso concedido no muestra nada', (
    tester,
    db,
  ) async {
    final permission = await pumpBudgets(
      tester,
      db,
      current: NotificationPermissionStatus.granted,
    );
    await saveBudget(tester, 'Transporte', '300000');

    expect(find.text('Presupuesto guardado'), findsOneWidget);
    expect(find.text(explanationTitle), findsNothing);
    expect(permission.requests, 0);
  });

  testWidgetsWithDatabase('"Ahora no" no muestra el diálogo del sistema ni '
      'vuelve a preguntar', (tester, db) async {
    final permission = await pumpBudgets(
      tester,
      db,
      current: NotificationPermissionStatus.denied,
    );
    await saveBudget(tester, 'Transporte', '300000');

    expect(find.text(explanationTitle), findsOneWidget);
    expect(find.textContaining('No mostramos montos'), findsOneWidget);
    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();
    expect(permission.requests, 0);

    await saveBudget(tester, 'Ocio', '200000');
    expect(find.text(explanationTitle), findsNothing);
    expect(permission.requests, 0);
  });

  for (final (answer, label) in [
    (NotificationPermissionStatus.granted, 'concedido'),
    (NotificationPermissionStatus.denied, 'negado'),
    (NotificationPermissionStatus.permanentlyDenied, 'negado permanente'),
  ]) {
    testWidgetsWithDatabase('"Permitir" pide el permiso una vez ($label) y '
        'no insiste', (tester, db) async {
      final permission = await pumpBudgets(
        tester,
        db,
        current: NotificationPermissionStatus.denied,
        onRequest: answer,
      );
      await saveBudget(tester, 'Transporte', '300000');
      await tester.tap(find.text('Permitir'));
      await tester.pumpAndSettle();
      expect(permission.requests, 1);
      expect(permission.current, answer);

      await saveBudget(tester, 'Ocio', '200000');
      expect(find.text(explanationTitle), findsNothing);
      expect(permission.requests, 1);
    });
  }

  testWidgetsWithDatabase('negado de forma permanente no explica nada', (
    tester,
    db,
  ) async {
    final permission = await pumpBudgets(
      tester,
      db,
      current: NotificationPermissionStatus.permanentlyDenied,
    );
    await saveBudget(tester, 'Transporte', '300000');

    expect(find.text(explanationTitle), findsNothing);
    expect(permission.requests, 0);
  });
}
