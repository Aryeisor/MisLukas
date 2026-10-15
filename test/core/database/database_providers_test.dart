import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/database/database_providers.dart';
import 'package:mislukas/core/utils/utils_providers.dart';
import 'package:mislukas/features/budgets/data/budgets_providers.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';
import 'package:mislukas/features/movements/data/movements_providers.dart';
import 'package:mislukas/features/movements/domain/entities/movement.dart';
import 'package:mislukas/features/reports/presentation/reports_providers.dart';
import 'package:mislukas/features/simulator/domain/get_savings_average.dart';
import 'package:mislukas/features/simulator/presentation/simulator_providers.dart';

import '../../helpers/domain_fixtures.dart';
import '../../helpers/test_database.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    final db = openTestDatabase();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(testClock),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
  });

  test(
    'registrar un gasto con los casos de uso actualiza el resumen',
    () async {
      await container.read(registerMovementProvider)(
        amount: 87400,
        categoryId: DefaultCategory.mercado.id,
        origin: MovementOrigin.manual,
        description: 'Éxito',
      );
      await container.read(setBudgetProvider)(
        categoryId: DefaultCategory.mercado.id,
        limitAmount: 100000,
      );

      final summary = await container.read(watchMonthSummaryProvider)().first;
      expect(summary.expenses, 87400);
      expect(summary.month, DateTime(2026, 9));

      final recent = await container.read(watchRecentMovementsProvider)().first;
      expect(recent.single.description, 'Éxito');

      final alerts = await container.read(evaluateBudgetAlertsProvider)();
      expect(alerts.single.percent, 87);

      final spending = await container
          .read(watchCategorySpendingProvider)()
          .first;
      expect(spending.single.percent, 100);

      expect(
        await container.read(getSavingsAverageProvider)(),
        isA<SavingsAverageInsufficientData>(),
      );
    },
  );

  test('el generador de identificadores crea UUID v4', () {
    final id = container.read(idGeneratorProvider).newId();
    expect(
      id,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });
}
