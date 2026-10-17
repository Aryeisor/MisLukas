import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/database/app_database.dart';
import 'package:mislukas/core/sync/sync_controller.dart';
import 'package:mislukas/core/sync/sync_service.dart';
import 'package:mislukas/core/utils/clock.dart';
import 'package:mislukas/features/auth/presentation/account_session_controller.dart';
import 'package:mislukas/features/budgets/data/drift_budget_repository.dart';
import 'package:mislukas/features/budgets/domain/entities/budget.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';
import 'package:mislukas/features/budgets/presentation/budget_carry_over_controller.dart';

import '../../../helpers/domain_fixtures.dart';
import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/test_container.dart';
import '../../../helpers/test_session.dart';

/// La continuidad corre después de cada intento de sincronización (RF-53).
/// Hoy es el 2 de octubre y septiembre tiene un presupuesto.
void main() {
  final octoberClock = FixedClock(DateTime(2026, 10, 2, 9));
  final october = DateTime(2026, 10);

  Future<(ProviderContainer, AppDatabase)> setUpContainer({
    FakeAuthRepository? auth,
    TestSession? session,
  }) async {
    final (container, db) = await createTestContainer(
      seed: false,
      clock: octoberClock,
      auth: auth,
      session: session,
    );
    await DriftBudgetRepository(db).save(
      Budget(
        id: 'septiembre',
        categoryId: DefaultCategory.mercado.id,
        month: DateTime(2026, 9),
        limitAmount: 500000,
      ),
      at: testToday,
    );
    container.listen(budgetCarryOverProvider, (_, _) {});
    return (container, db);
  }

  test(
    'al terminar una sincronización copia el mes; la siguiente no duplica',
    () async {
      final (container, db) = await setUpContainer();
      await waitForState(
        container,
        accountSessionProvider,
        (s) => s == AccountSessionStatus.ready,
      );

      await container.read(syncControllerProvider.notifier).syncNow();
      await waitForState(
        container,
        budgetCarryOverProvider,
        (runs) => runs == 1,
      );
      final budgets = DriftBudgetRepository(db);
      final copied = await budgets.getForMonth(october);
      expect(copied.single.limitAmount, 500000);
      expect(copied.single.id, isNot('septiembre'));

      await container.read(syncControllerProvider.notifier).syncNow();
      await waitForState(
        container,
        budgetCarryOverProvider,
        (runs) => runs == 2,
      );
      expect(await budgets.getForMonth(october), hasLength(1));
    },
  );

  test('sin conexión también copia', () async {
    final session = TestSession();
    session.server.offline = true;
    final (container, db) = await setUpContainer(session: session);
    await waitForState(
      container,
      accountSessionProvider,
      (s) => s == AccountSessionStatus.ready,
    );

    final result = await container
        .read(syncControllerProvider.notifier)
        .syncNow();
    expect(result, SyncResult.offline);
    await waitForState(container, budgetCarryOverProvider, (runs) => runs == 1);
    expect(await DriftBudgetRepository(db).getForMonth(october), hasLength(1));
  });

  test('sin sesión no hace nada', () async {
    final (container, db) = await setUpContainer(auth: FakeAuthRepository());

    await container.read(syncControllerProvider.notifier).syncNow();
    await Future<void>.delayed(Duration.zero);

    expect(container.read(budgetCarryOverProvider), 0);
    expect(await DriftBudgetRepository(db).getForMonth(october), isEmpty);
  });
}
