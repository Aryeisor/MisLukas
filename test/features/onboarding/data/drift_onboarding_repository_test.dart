import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/database/app_database.dart';
import 'package:mislukas/features/budgets/data/drift_budget_repository.dart';
import 'package:mislukas/features/budgets/domain/entities/budget.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';
import 'package:mislukas/features/movements/data/drift_movement_repository.dart';
import 'package:mislukas/features/onboarding/data/drift_onboarding_repository.dart';

import '../../../helpers/domain_fixtures.dart';
import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftOnboardingRepository repository;

  setUp(() {
    db = openTestDatabase();
    repository = DriftOnboardingRepository(db);
  });
  tearDown(() => db.close());

  test('la marca empieza vacía, se guarda y repetirla no falla', () async {
    expect(await repository.isWelcomeDone(), isFalse);
    await repository.markWelcomeDone();
    await repository.markWelcomeDone();
    expect(await repository.isWelcomeDone(), isTrue);
    expect(await db.select(db.localSettings).get(), hasLength(1));
  });

  test('la marca no entra a la cola de sincronización', () async {
    await repository.markWelcomeDone();
    expect(await db.select(db.syncQueue).get(), isEmpty);
  });

  test('una base nueva (solo categorías predeterminadas) no tiene datos', () async {
    expect(await repository.hasOwnData(), isFalse);
  });

  test('un movimiento, aunque esté eliminado, cuenta como dato', () async {
    final movements = DriftMovementRepository(db);
    await movements.add(testMovement(id: 'm1'));
    expect(await repository.hasOwnData(), isTrue);

    await movements.softDelete('m1', at: testToday);
    expect(await repository.hasOwnData(), isTrue);
  });

  test('un presupuesto cuenta como dato', () async {
    await DriftBudgetRepository(db).save(
      Budget(
        id: 'b1',
        categoryId: DefaultCategory.mercado.id,
        month: DateTime(2026, 9),
        limitAmount: 800000,
      ),
      at: testToday,
    );
    expect(await repository.hasOwnData(), isTrue);
  });

  test('una categoría personalizada cuenta como dato', () async {
    await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            id: 'propia',
            name: 'Mascotas',
            type: 'gasto',
            createdAt: testToday,
            updatedAt: testToday,
          ),
        );
    expect(await repository.hasOwnData(), isTrue);
  });
}
