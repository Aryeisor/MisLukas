import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/features/budgets/data/budgets_providers.dart';
import 'package:mislukas/features/budgets/domain/entities/budget_alert.dart';
import 'package:mislukas/features/budgets/domain/entities/budget_alert_notice.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';
import 'package:mislukas/features/budgets/domain/repositories/notification_services.dart';
import 'package:mislukas/features/movements/data/movements_providers.dart';
import 'package:mislukas/features/movements/domain/entities/movement.dart';

import '../../../helpers/fake_sync_server.dart';
import '../../../helpers/test_container.dart';
import '../../../helpers/test_session.dart';

/// Alertas de presupuesto (RF-30 a RF-32): una sola notificación por
/// categoría, umbral y mes. Presupuesto de Mercado de $100.000 en octubre.
void main() {
  late ProviderContainer container;
  late TestSession session;
  late MutableClock clock;

  setUp(() async {
    clock = MutableClock(DateTime(2026, 10, 10, 9));
    session = TestSession();
    (container, _) = await createTestContainer(
      seed: false,
      clock: clock,
      session: session,
    );
  });

  Future<List<BudgetAlertNotice>> notify() =>
      container.read(notifyBudgetAlertsProvider).call();

  Future<String> setBudget(
    int limit, {
    DefaultCategory category = DefaultCategory.mercado,
  }) async {
    final budget = await container
        .read(setBudgetProvider)
        .call(categoryId: category.id, limitAmount: limit);
    return budget.id;
  }

  Future<String> spend(
    int amount, {
    DefaultCategory category = DefaultCategory.mercado,
  }) async {
    final movement = await container
        .read(registerMovementProvider)
        .call(
          amount: amount,
          categoryId: category.id,
          origin: MovementOrigin.manual,
        );
    return movement.id;
  }

  Future<Set<SentBudgetAlert>> sent() => container
      .read(budgetAlertLogProvider)
      .sentFor(DateTime(clock.now().year, clock.now().month));

  group('línea base', () {
    test('registra lo ya cruzado sin notificar', () async {
      await setBudget(100000);
      await spend(80000);

      expect(await notify(), isEmpty);
      expect(await container.read(budgetAlertLogProvider).hasBaseline(), true);
      expect(await sent(), {
        (DefaultCategory.mercado.id, BudgetAlertThreshold.warning),
      });
      // Lo cruzado antes no vuelve a salir.
      expect(await notify(), isEmpty);
      expect(session.notifier.shown, isEmpty);
    });
  });

  group('después de la línea base', () {
    setUp(() async {
      // Línea base de una base vacía: después, todo lo nuevo se notifica.
      expect(await notify(), isEmpty);
      await setBudget(100000);
    });

    test('74% no alerta', () async {
      await spend(74999);
      expect(await notify(), isEmpty);
      expect(await sent(), isEmpty);
    });

    test('75% alerta una vez; otro gasto en el mes no la repite', () async {
      await spend(75000);
      final shown = await notify();
      expect(shown.single.body, 'Llevas el 75% de tu presupuesto de Mercado.');
      expect(session.notifier.shown, shown);

      await spend(5000);
      expect(await notify(), isEmpty);
      expect(session.notifier.shown, hasLength(1));
    });

    test('100% alerta una vez después del 75%', () async {
      await spend(80000);
      await notify();
      await spend(20000);
      final shown = await notify();
      expect(
        shown.single.body,
        'Llegaste al 100% de tu presupuesto de Mercado de octubre.',
      );

      await spend(10000);
      expect(await notify(), isEmpty);
      expect(session.notifier.shown, hasLength(2));
    });

    test('un gasto que cruza los dos umbrales muestra solo el 100%', () async {
      await spend(130000);
      final shown = await notify();
      expect(
        shown.single.body,
        'Superaste tu presupuesto de Mercado de octubre.',
      );
      expect(await sent(), {
        (DefaultCategory.mercado.id, BudgetAlertThreshold.warning),
        (DefaultCategory.mercado.id, BudgetAlertThreshold.exceeded),
      });
    });

    test('si el gasto baja y vuelve a subir no repite el umbral', () async {
      final id = await spend(80000);
      expect(await notify(), hasLength(1));

      await container.read(deleteMovementProvider).call(id);
      expect(await notify(), isEmpty);
      await spend(80000);
      expect(await notify(), isEmpty);
      expect(session.notifier.shown, hasLength(1));
    });

    test('si sube el límite no repite el umbral', () async {
      await spend(80000);
      expect(await notify(), hasLength(1));

      await setBudget(200000);
      await spend(80000); // 80% del límite nuevo
      expect(await notify(), isEmpty);
    });

    test('editar un gasto hasta el 90% alerta', () async {
      final id = await spend(10000);
      expect(await notify(), isEmpty);
      await container.read(updateMovementProvider).call(id: id, amount: 90000);
      expect((await notify()).single.percent, 90);
    });

    test('el mes siguiente vuelve a alertar', () async {
      await spend(80000);
      expect(await notify(), hasLength(1));

      clock.current = DateTime(2026, 11, 3, 9);
      await setBudget(100000);
      await spend(76000);
      final shown = await notify();
      expect(shown.single.month, DateTime(2026, 11));
      expect(shown.single.percent, 76);
    });

    test('los ingresos no cuentan', () async {
      await container.read(registerIncomeProvider).call(amount: 5000000);
      expect(await notify(), isEmpty);
    });

    test('una categoría sin presupuesto no alerta', () async {
      await spend(900000, category: DefaultCategory.transporte);
      expect(await notify(), isEmpty);
    });

    test('un presupuesto eliminado no alerta', () async {
      final id = await setBudget(50000, category: DefaultCategory.ocio);
      await container.read(removeBudgetProvider).call(id);
      await spend(60000, category: DefaultCategory.ocio);
      expect(await notify(), isEmpty);
    });

    test(
      'con el interruptor apagado registra sin notificar; al activarlo no '
      'llegan avisos viejos',
      () async {
        final settings = container.read(
          notificationSettingsRepositoryProvider,
        );
        await settings.setEnabled(false);
        await spend(80000);
        expect(await notify(), isEmpty);
        expect(await sent(), isNotEmpty);

        await settings.setEnabled(true);
        expect(await notify(), isEmpty);
        expect(session.notifier.shown, isEmpty);
      },
    );

    test('sin permiso registra sin notificar', () async {
      session.notificationPermission.current =
          NotificationPermissionStatus.denied;
      await spend(80000);
      expect(await notify(), isEmpty);
      expect(await sent(), isNotEmpty);
    });

    test(
      'si la notificación falla, queda registrada y no se reintenta',
      () async {
        session.notifier.fail = true;
        await spend(80000);
        expect(await notify(), isEmpty);
        session.notifier.fail = false;
        expect(await notify(), isEmpty);
        expect(session.notifier.shown, isEmpty);
      },
    );
  });
}
