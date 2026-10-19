import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/sync/sync_controller.dart';
import 'package:mislukas/core/sync/sync_service.dart';
import 'package:mislukas/core/utils/clock.dart';
import 'package:mislukas/features/auth/presentation/account_session_controller.dart';
import 'package:mislukas/features/budgets/data/budgets_providers.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';
import 'package:mislukas/features/budgets/presentation/budget_alert_notification_controller.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/sync_device.dart';
import '../../../helpers/test_container.dart';
import '../../../helpers/test_session.dart';

/// Las alertas se evalúan cuando cambian los datos del mes, también los que
/// llegan por sincronización desde otro celular. Hoy es el 22 de septiembre.
void main() {
  final septemberClock = FixedClock(DateTime(2026, 9, 22, 9));

  late ProviderContainer container;
  late TestSession session;
  late SyncDevice otherPhone;

  setUp(() async {
    session = TestSession();
    (container, _) = await createTestContainer(
      seed: false,
      clock: septemberClock,
      session: session,
    );
    otherPhone = SyncDevice(session.server, userId: testUser.id, idPrefix: 'b');
    addTearDown(otherPhone.close);
    container.listen(budgetAlertNotificationProvider, (_, _) {});
    await waitForState(
      container,
      accountSessionProvider,
      (s) => s == AccountSessionStatus.ready,
    );
  });

  Future<void> sync() async {
    expect(
      await container.read(syncControllerProvider.notifier).syncNow(),
      SyncResult.ok,
    );
  }

  /// Espera a que [condition] se cumpla (las evaluaciones son asíncronas).
  Future<void> eventually(Future<bool> Function() condition) async {
    for (var i = 0; i < 100; i++) {
      if (await condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    fail('La condición no se cumplió');
  }

  Future<bool> hasBaseline() =>
      container.read(budgetAlertLogProvider).hasBaseline();

  test('la primera sincronización de una base nueva no notifica lo que trae '
      'el servidor', () async {
    await otherPhone.saveBudget(100000);
    await otherPhone.addMovement(amount: 90000);
    await otherPhone.sync();

    // Antes de sincronizar no se evalúa nada.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(await hasBaseline(), false);

    await sync();
    await eventually(hasBaseline);
    // El 90% quedó registrado como línea base, sin notificar.
    final sent = await container
        .read(budgetAlertLogProvider)
        .sentFor(DateTime(2026, 9));
    expect(sent, hasLength(1));
    expect(session.notifier.shown, isEmpty);
  });

  test('un gasto que llega por sincronización notifica', () async {
    await container
        .read(setBudgetProvider)
        .call(categoryId: DefaultCategory.mercado.id, limitAmount: 100000);
    await sync();
    await eventually(hasBaseline);
    expect(session.notifier.shown, isEmpty);

    await otherPhone.addMovement(amount: 80000);
    await otherPhone.sync();
    await sync();

    await eventually(() async => session.notifier.shown.isNotEmpty);
    expect(
      session.notifier.shown.single.body,
      'Llevas el 80% de tu presupuesto de Mercado.',
    );
  });

  test('sin sesión no evalúa nada', () async {
    final (signedOut, _) = await createTestContainer(
      seed: false,
      clock: septemberClock,
      auth: FakeAuthRepository(),
      session: TestSession(),
    );
    signedOut.listen(budgetAlertNotificationProvider, (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(await signedOut.read(budgetAlertLogProvider).hasBaseline(), false);
  });
}
