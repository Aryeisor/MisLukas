import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/database/app_database.dart';
import 'package:mislukas/core/sync/sync_status.dart';
import 'package:mislukas/features/movements/data/drift_movement_repository.dart';
import 'package:mislukas/features/movements/domain/entities/movement.dart';
import 'package:mislukas/features/movements/domain/entities/receipt.dart';

import '../../../helpers/domain_fixtures.dart';
import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftMovementRepository repository;

  setUp(() {
    db = openTestDatabase();
    repository = DriftMovementRepository(db);
  });
  tearDown(() => db.close());

  Future<List<SyncQueueEntry>> queue() =>
      (db.select(db.syncQueue)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();

  Future<String> rawSyncStatus(String id) async {
    final row = await (db.select(
      db.movements,
    )..where((t) => t.id.equals(id))).getSingle();
    return row.syncStatus;
  }

  test('crear: queda pendiente y entra a la cola', () async {
    final movement = testMovement(id: 'm1', amount: 87400, note: 'Éxito');
    await repository.add(movement);

    expect(await repository.findById('m1'), movement);
    expect(await rawSyncStatus('m1'), 'pendiente');

    final entry = (await queue()).single;
    expect(entry.targetTable, 'movimientos');
    expect(entry.recordId, 'm1');
    expect(entry.operation, 'crear');
    expect(entry.attempts, 0);
    expect(entry.createdAt.isAtSameMomentAs(movement.updatedAt), isTrue);
  });

  test(
    'aunque la entidad diga sincronizado, toda escritura queda pendiente',
    () async {
      await repository.add(
        testMovement(id: 'm1').copyWith(syncStatus: SyncStatus.synced),
      );
      expect((await repository.findById('m1'))!.syncStatus, SyncStatus.pending);
    },
  );

  test('editar: cambia los datos, conserva creado_en y encola', () async {
    final movement = testMovement(id: 'm1', amount: 1000);
    await repository.add(movement);
    final edited = movement.copyWith(
      amount: 2000,
      updatedAt: testToday.add(const Duration(minutes: 5)),
    );
    await repository.update(edited);

    expect(await repository.findById('m1'), edited);
    expect((await queue()).map((e) => e.operation), ['crear', 'actualizar']);
  });

  test(
    'editar un movimiento inexistente revierte la entrada de la cola',
    () async {
      await expectLater(
        repository.update(testMovement(id: 'fantasma')),
        throwsStateError,
      );
      expect(await queue(), isEmpty);
    },
  );

  test('eliminar: borrado lógico, pendiente y encolado', () async {
    await repository.add(testMovement(id: 'm1'));
    final deletedAt = testToday.add(const Duration(hours: 2));
    await repository.softDelete('m1', at: deletedAt);

    expect(await repository.findById('m1'), isNull);
    final row = await (db.select(
      db.movements,
    )..where((t) => t.id.equals('m1'))).getSingle();
    expect(row.deletedAt!.isAtSameMomentAs(deletedAt), isTrue);
    expect(row.updatedAt.isAtSameMomentAs(deletedAt), isTrue);
    expect(row.syncStatus, 'pendiente');
    expect((await queue()).map((e) => e.operation), ['crear', 'eliminar']);

    // Eliminar de nuevo falla y no deja otra entrada.
    await expectLater(
      repository.softDelete('m1', at: deletedAt),
      throwsStateError,
    );
    expect(await queue(), hasLength(2));
  });

  test('recibo: se guarda con el movimiento y se elimina con él', () async {
    final movement = testMovement(id: 'm1', origin: MovementOrigin.photo);
    await repository.add(
      movement,
      receipt: const Receipt(
        id: 'r1',
        movementId: 'm1',
        localPath: 'recibos/r1.jpg',
        detectedTotal: 87400,
        detectedMerchant: 'Éxito',
      ),
    );
    await repository.softDelete('m1', at: testToday);

    final receipt = await db.select(db.receipts).getSingle();
    expect(receipt.deletedAt, isNotNull);
    expect((await queue()).map((e) => '${e.targetTable}:${e.operation}'), [
      'movimientos:crear',
      'recibos:crear',
      'movimientos:eliminar',
      'recibos:eliminar',
    ]);
  });

  test('un movimiento tiene como máximo un recibo', () async {
    const receipt = Receipt(id: 'r1', movementId: 'm1', localPath: 'a.jpg');
    await repository.add(testMovement(id: 'm1'), receipt: receipt);
    await expectLater(
      db
          .into(db.receipts)
          .insert(
            const Receipt(
              id: 'r2',
              movementId: 'm1',
              localPath: 'b.jpg',
            ).toCompanionForTest(),
          ),
      throwsA(anything),
    );
  });

  test(
    'CHECK rechaza monto 0 o negativo sin dejar entrada en la cola',
    () async {
      for (final amount in [0, -5000]) {
        await expectLater(
          repository.add(testMovement(amount: amount)),
          throwsA(anything),
        );
      }
      expect(await db.select(db.movements).get(), isEmpty);
      expect(await queue(), isEmpty);
    },
  );

  test('recientes y por rango, del más reciente al más antiguo', () async {
    await repository.add(testMovement(id: 'ago', date: DateTime(2026, 8, 31)));
    await repository.add(testMovement(id: 's1', date: DateTime(2026, 9, 1)));
    await repository.add(testMovement(id: 's30', date: DateTime(2026, 9, 30)));
    await repository.add(testMovement(id: 'oct', date: DateTime(2026, 10, 1)));
    await repository.add(
      testMovement(id: 'borrado', date: DateTime(2026, 9, 5)),
    );
    await repository.softDelete('borrado', at: testToday);

    final september = await repository.getBetween(
      DateTime(2026, 9),
      DateTime(2026, 10),
    );
    expect(september.map((m) => m.id), ['s30', 's1']);

    final recent = await repository.watchRecent(limit: 2).first;
    expect(recent.map((m) => m.id), ['oct', 's30']);
  });

  test('los streams emiten al insertar', () async {
    final stream = repository.watchBetween(
      DateTime(2026, 9),
      DateTime(2026, 10),
    );
    final expectation = expectLater(
      stream.map((list) => list.map((m) => m.id).toList()),
      emitsInOrder([
        isEmpty,
        ['m1'],
      ]),
    );
    await pumpEventQueue();
    await repository.add(testMovement(id: 'm1'));
    await expectation;
  });

  test('textos con comillas y SQL se guardan como texto (consultas parametrizadas)', () async {
    const evil = "'; DROP TABLE movimientos; --";
    await repository.add(testMovement(id: 'm1', description: evil, note: evil));
    final saved = await repository.findById('m1');
    expect(saved!.description, evil);
    expect(await db.select(db.movements).get(), hasLength(1));
  });
}

extension on Receipt {
  ReceiptsCompanion toCompanionForTest() => ReceiptsCompanion.insert(
    id: id,
    movementId: movementId,
    localPath: localPath,
    createdAt: DateTime.utc(2026, 9, 22),
    updatedAt: DateTime.utc(2026, 9, 22),
  );
}
