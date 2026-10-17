import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/errors/domain_exception.dart';
import 'package:mislukas/core/sync/sync_status.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';
import 'package:mislukas/features/movements/domain/entities/movement.dart';
import 'package:mislukas/features/movements/domain/movement_text.dart';
import 'package:mislukas/features/movements/domain/usecases/register_income.dart';
import 'package:mislukas/features/movements/domain/usecases/register_movement.dart';

import '../../../helpers/domain_fixtures.dart';
import '../../../helpers/fake_repositories.dart';

Matcher throwsDomain(DomainError error) =>
    throwsA(isA<DomainException>().having((e) => e.error, 'error', error));

void main() {
  late FakeMovementRepository movements;
  late RegisterIncome registerIncome;

  setUp(() {
    movements = FakeMovementRepository();
    registerIncome = RegisterIncome(
      RegisterMovement(
        movements: movements,
        categories: FakeCategoryRepository(),
        clock: testClock,
        ids: SequentialIdGenerator(),
      ),
    );
  });

  test('usa la categoría Ingreso, tipo ingreso, origen manual y hoy', () async {
    final income = await registerIncome(amount: 3800000, description: 'Salario');

    expect(income.categoryId, DefaultCategory.ingreso.id);
    expect(income.type, MovementType.income);
    expect(income.isIncome, isTrue);
    expect(income.origin, MovementOrigin.manual);
    expect(income.amount, 3800000);
    expect(income.description, 'Salario');
    expect(income.note, isNull);
    expect(income.date, DateTime(2026, 9, 22));
    expect(income.syncStatus, SyncStatus.pending);
    expect(await movements.findById(income.id), income);
  });

  test('no guarda recibo', () async {
    await registerIncome(amount: 450000);
    expect(movements.receipts, isEmpty);
  });

  test('acepta una fecha pasada', () async {
    final income = await registerIncome(
      amount: 450000,
      description: 'Freelance',
      date: DateTime(2026, 9, 1, 18),
    );
    expect(income.date, DateTime(2026, 9, 1));
  });

  test('sin descripción usa "Ingreso"', () async {
    final income = await registerIncome(amount: 450000, description: '   ');
    expect(income.description, 'Ingreso');
  });

  for (final amount in [null, 0, -1000]) {
    test('rechaza el monto $amount', () {
      expect(
        registerIncome(amount: amount, description: 'Salario'),
        throwsDomain(DomainError.invalidAmount),
      );
    });
  }

  test('rechaza una descripción de más de 200 caracteres', () {
    expect(
      registerIncome(
        amount: 1000,
        description: 'a' * (movementTextMaxLength + 1),
      ),
      throwsDomain(DomainError.textTooLong),
    );
  });

  test('rechaza una fecha futura, igual que un gasto', () {
    expect(
      registerIncome(amount: 1000, date: DateTime(2026, 9, 23)),
      throwsDomain(DomainError.futureDate),
    );
  });

  test('un rechazo no guarda nada', () async {
    await expectLater(
      registerIncome(amount: 0),
      throwsDomain(DomainError.invalidAmount),
    );
    expect(await movements.getBetween(DateTime(2000), DateTime(2100)), isEmpty);
  });
}
