import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/errors/domain_exception.dart';
import 'package:mislukas/core/sync/sync_status.dart';
import 'package:mislukas/core/utils/clock.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';
import 'package:mislukas/features/movements/domain/entities/month_summary.dart';
import 'package:mislukas/features/movements/domain/entities/movement.dart';
import 'package:mislukas/features/movements/domain/movement_text.dart';
import 'package:mislukas/features/movements/domain/usecases/delete_movement.dart';
import 'package:mislukas/features/movements/domain/usecases/register_movement.dart';
import 'package:mislukas/features/movements/domain/usecases/update_movement.dart';
import 'package:mislukas/features/movements/domain/usecases/watch_month_summary.dart';
import 'package:mislukas/features/movements/domain/usecases/watch_recent_movements.dart';

import '../../../helpers/domain_fixtures.dart';
import '../../../helpers/fake_repositories.dart';

Matcher throwsDomain(DomainError error) =>
    throwsA(isA<DomainException>().having((e) => e.error, 'error', error));

void main() {
  // Una hora después de testToday, para distinguir creación de edición.
  final oneHourLater = FixedClock(testToday.add(const Duration(hours: 1)));
  late FakeMovementRepository movements;
  late FakeCategoryRepository categories;

  setUp(() {
    movements = FakeMovementRepository();
    categories = FakeCategoryRepository();
  });

  group('RegisterMovement', () {
    late RegisterMovement register;

    setUp(() {
      register = RegisterMovement(
        movements: movements,
        categories: categories,
        clock: testClock,
        ids: SequentialIdGenerator(),
      );
    });

    test('guarda un gasto pendiente con fecha de hoy', () async {
      final movement = await register(
        amount: 87400,
        categoryId: DefaultCategory.mercado.id,
        origin: MovementOrigin.manual,
        description: ' Éxito ',
      );

      expect(movement.id, 'id-1');
      expect(movement.type, MovementType.expense);
      expect(movement.amount, 87400);
      expect(movement.date, DateTime(2026, 9, 22));
      expect(movement.description, 'Éxito');
      expect(movement.note, isNull);
      expect(movement.account, 'principal');
      expect(movement.createdAt, testToday);
      expect(movement.syncStatus, SyncStatus.pending);
      expect(await movements.findById('id-1'), movement);
    });

    test('el tipo sale de la categoría: Ingreso registra un ingreso', () async {
      final movement = await register(
        amount: 3800000,
        categoryId: DefaultCategory.ingreso.id,
        origin: MovementOrigin.manual,
        description: 'Salario',
      );
      expect(movement.type, MovementType.income);
    });

    test('sin descripción usa el nombre de la categoría', () async {
      final movement = await register(
        amount: 5600,
        categoryId: DefaultCategory.transporte.id,
        origin: MovementOrigin.manual,
      );
      expect(movement.description, 'Transporte');
    });

    test('rechaza monto vacío, cero y negativo (RF-20)', () async {
      for (final amount in [null, 0, -100]) {
        await expectLater(
          register(
            amount: amount,
            categoryId: DefaultCategory.mercado.id,
            origin: MovementOrigin.manual,
          ),
          throwsDomain(DomainError.invalidAmount),
        );
      }
      expect(movements.all, isEmpty);
    });

    test('rechaza una categoría inexistente', () async {
      await expectLater(
        register(
          amount: 1000,
          categoryId: 'no-existe',
          origin: MovementOrigin.manual,
        ),
        throwsDomain(DomainError.categoryNotFound),
      );
    });

    test('rechaza fechas posteriores a hoy; hoy y el pasado sí', () async {
      await expectLater(
        register(
          amount: 1000,
          categoryId: DefaultCategory.mercado.id,
          origin: MovementOrigin.manual,
          date: DateTime(2026, 9, 23),
        ),
        throwsDomain(DomainError.futureDate),
      );
      expect(movements.all, isEmpty);

      // Hoy a una hora posterior a la del reloj sigue siendo hoy.
      final today = await register(
        amount: 1000,
        categoryId: DefaultCategory.mercado.id,
        origin: MovementOrigin.manual,
        date: DateTime(2026, 9, 22, 23, 59),
      );
      expect(today.date, DateTime(2026, 9, 22));

      final past = await register(
        amount: 1000,
        categoryId: DefaultCategory.mercado.id,
        origin: MovementOrigin.manual,
        date: DateTime(2025, 12, 31),
      );
      expect(past.date, DateTime(2025, 12, 31));
    });

    test(
      'rechaza notas de más de 200 caracteres y limpia las válidas',
      () async {
        await expectLater(
          register(
            amount: 1000,
            categoryId: DefaultCategory.ocio.id,
            origin: MovementOrigin.manual,
            note: 'a' * (movementTextMaxLength + 1),
          ),
          throwsDomain(DomainError.textTooLong),
        );

        final movement = await register(
          amount: 1000,
          categoryId: DefaultCategory.ocio.id,
          origin: MovementOrigin.manual,
          note: '  café\u0007  ',
        );
        expect(movement.note, 'café');
      },
    );

    test('por foto guarda el recibo con los datos del OCR limpios', () async {
      final movement = await register(
        amount: 87400,
        categoryId: DefaultCategory.mercado.id,
        origin: MovementOrigin.photo,
        receipt: const ReceiptDraft(
          localPath: 'recibos/1.jpg',
          detectedTotal: 87400,
          detectedMerchant: ' ÉXITO\u0000 ',
        ),
      );
      final receipt = movements.receipts.values.single;
      expect(receipt.movementId, movement.id);
      expect(receipt.detectedMerchant, 'ÉXITO');
      expect(receipt.detectedTotal, 87400);
    });
  });

  group('UpdateMovement', () {
    late UpdateMovement update;
    late Movement original;

    setUp(() async {
      original = testMovement(id: 'm', amount: 1000, note: 'nota');
      await movements.add(original);
      update = UpdateMovement(
        movements: movements,
        categories: categories,
        clock: oneHourLater,
      );
    });

    test('cambia solo los campos indicados y queda pendiente', () async {
      final updated = await update(id: 'm', amount: 2500);
      expect(updated.amount, 2500);
      expect(updated.note, 'nota');
      expect(updated.createdAt, original.createdAt);
      expect(updated.updatedAt, oneHourLater.now());
      expect(updated.syncStatus, SyncStatus.pending);
      expect(await movements.findById('m'), updated);
    });

    test('cambiar a Ingreso cambia el tipo; la nota se puede borrar', () async {
      final updated = await update(
        id: 'm',
        categoryId: DefaultCategory.ingreso.id,
        note: () => null,
      );
      expect(updated.type, MovementType.income);
      expect(updated.note, isNull);
    });

    test('valida monto y existencia', () async {
      await expectLater(
        update(id: 'm', amount: 0),
        throwsDomain(DomainError.invalidAmount),
      );
      await expectLater(
        update(id: 'otro', amount: 10),
        throwsDomain(DomainError.movementNotFound),
      );
      await expectLater(
        update(id: 'm', categoryId: 'no-existe'),
        throwsDomain(DomainError.categoryNotFound),
      );
      expect((await movements.findById('m'))!.amount, 1000);
    });

    test('rechaza cambiar la fecha a una posterior a hoy', () async {
      await expectLater(
        update(id: 'm', date: DateTime(2026, 10, 1)),
        throwsDomain(DomainError.futureDate),
      );
      expect((await movements.findById('m'))!.date, original.date);

      final updated = await update(id: 'm', date: DateTime(2026, 9, 1));
      expect(updated.date, DateTime(2026, 9, 1));
    });
  });

  group('DeleteMovement', () {
    test('borrado lógico con la hora del reloj', () async {
      await movements.add(testMovement(id: 'm'));
      await DeleteMovement(movements: movements, clock: testClock)('m');

      expect(await movements.findById('m'), isNull);
      expect(movements.all.single.deletedAt, testToday);
    });

    test('no existe o ya eliminado', () async {
      final delete = DeleteMovement(movements: movements, clock: testClock);
      await expectLater(
        delete('nada'),
        throwsDomain(DomainError.movementNotFound),
      );
    });
  });

  test('WatchRecentMovements: los 5 más recientes, sin eliminados', () async {
    for (var day = 1; day <= 7; day++) {
      await movements.add(
        testMovement(id: 'd$day', date: DateTime(2026, 9, day)),
      );
    }
    await movements.softDelete('d7', at: testToday);

    final recent = await WatchRecentMovements(movements: movements)().first;
    expect(recent.map((m) => m.id), ['d6', 'd5', 'd4', 'd3', 'd2']);
  });

  test('WatchMonthSummary: Inicio de la Fase 3 y se actualiza', () async {
    final repository = FakeMovementRepository(phase3Movements());
    final summaries = WatchMonthSummary(
      movements: repository,
      clock: testClock,
    )();

    final expectation = expectLater(
      summaries,
      emitsInOrder([
        isA<MonthSummary>()
            .having((s) => s.income, 'income', 4250000)
            .having((s) => s.expenses, 'expenses', 2375680)
            .having((s) => s.available, 'available', 1874320)
            .having((s) => s.month, 'month', DateTime(2026, 9)),
        isA<MonthSummary>().having((s) => s.expenses, 'expenses', 2463080),
      ]),
    );
    await Future<void>.delayed(Duration.zero);
    await repository.add(testMovement(amount: 87400));
    await expectation;
  });
}
