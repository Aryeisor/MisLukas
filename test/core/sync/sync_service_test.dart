import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/sync/local_sync_store.dart';
import 'package:mislukas/core/sync/sync_service.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';
import 'package:mislukas/features/movements/domain/entities/receipt.dart';

import '../../helpers/fake_sync_server.dart';
import '../../helpers/sync_device.dart';

void main() {
  late FakeSyncServer server;
  late SyncDevice device;

  setUp(() {
    server = FakeSyncServer();
    device = SyncDevice(server);
  });
  tearDown(() => device.close());

  /// Fila remota de un movimiento de [userA] (otro dispositivo).
  Map<String, dynamic> remoteMovement(
    String id, {
    int amount = 5000,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    final updated = (updatedAt ?? DateTime.utc(2026, 9, 22, 15)).toUtc();
    return {
      'id': id,
      'categoria_id': DefaultCategory.transporte.id,
      'tipo': 'gasto',
      'monto': amount,
      'fecha': '2026-09-21',
      'descripcion': 'Remoto',
      'nota': null,
      'origen': 'manual',
      'cuenta': 'principal',
      'creado_en': '2026-09-21T12:00:00.000Z',
      'actualizado_en': updated.toIso8601String(),
      'eliminado_en': deletedAt?.toUtc().toIso8601String(),
    };
  }

  List<String> upsertTables() => [
    for (final call in server.calls)
      if (call.method == 'upsert') call.table,
  ];

  group('push', () {
    test(
      'envía en el orden de las llaves foráneas y deja todo sincronizado',
      () async {
        await device.saveBudget(800000);
        await device.addMovement(
          receipt: (movementId) => Receipt(
            id: 'r-1',
            movementId: movementId,
            localPath: 'recibos/r-1.jpg',
            detectedTotal: 10000,
          ),
        );

        expect(await device.sync(), SyncResult.ok);

        expect(upsertTables(), ['movimientos', 'presupuestos', 'recibos']);
        expect(await device.queue(), isEmpty);
        for (final row in await device.allMovements()) {
          expect(row.syncStatus, 'sincronizado');
        }
        final receipt = server.row('recibos', 'r-1')!;
        expect(receipt['usuario_id'], userA);
        // La ruta local nunca sale del dispositivo.
        expect(receipt.containsKey('ruta_local'), isFalse);
      },
    );

    test(
      'varias entradas de un registro se envían como un solo upsert',
      () async {
        final id = await device.addMovement(amount: 1000);
        device.clock.advance(const Duration(minutes: 1));
        await device.editMovement(id, amount: 2000);
        device.clock.advance(const Duration(minutes: 1));
        await device.editMovement(id, amount: 3000);
        expect(await device.queue(), hasLength(3));

        await device.sync();

        final upserts = server.calls.where((c) => c.method == 'upsert');
        expect(upserts.single.ids, [id]);
        expect(server.row('movimientos', id)!['monto'], 3000);
      },
    );

    test('envía en lotes de 100', () async {
      for (var i = 0; i < 230; i++) {
        await device.addMovement(amount: 1000 + i);
      }
      await device.sync();
      final sizes = [
        for (final call in server.calls)
          if (call.method == 'upsert') call.ids.length,
      ];
      expect(sizes, [100, 100, 30]);
      expect(server.rows('movimientos'), hasLength(230));
    });

    test('una edición durante el envío no se marca como enviada', () async {
      final id = await device.addMovement(amount: 1000);
      var edited = false;
      server.onUpsert = (table, rows) async {
        if (edited) return;
        edited = true;
        device.clock.advance(const Duration(seconds: 5));
        await device.editMovement(id, amount: 9000);
      };

      await device.sync();

      // La confirmación del primer envío no marcó la edición como
      // enviada: la segunda pasada del push la envió en la misma
      // sincronización.
      final upserts = [
        for (final call in server.calls)
          if (call.method == 'upsert') call.ids,
      ];
      expect(upserts, [
        [id],
        [id],
      ]);
      expect(server.row('movimientos', id)!['monto'], 9000);
      expect(await device.queue(), isEmpty);
      expect((await device.movement(id))!.syncStatus, 'sincronizado');
    });

    test('sin conexión no marca nada ni pierde la cola', () async {
      final id = await device.addMovement();
      server.offline = true;

      expect(await device.sync(), SyncResult.offline);

      final queue = await device.queue();
      expect(queue.single.attempts, 0);
      expect(queue.single.lastError, isNull);
      expect((await device.movement(id))!.syncStatus, 'pendiente');

      server.offline = false;
      expect(await device.sync(), SyncResult.ok);
      expect(await device.queue(), isEmpty);
    });

    test('sin sesión válida se detiene sin marcar nada', () async {
      await device.addMovement();
      server.sessionRejected = true;
      expect(await device.sync(), SyncResult.unauthorized);
      expect((await device.queue()).single.attempts, 0);
    });

    test(
      'un registro rechazado no bloquea a los demás ni se reintenta en bucle',
      () async {
        final bad = await device.addMovement(amount: 1);
        final good1 = await device.addMovement(amount: 2);
        final good2 = await device.addMovement(amount: 3);
        server.rejectedIds[bad] = '23514';

        expect(await device.sync(), SyncResult.ok);

        expect(server.row('movimientos', good1), isNotNull);
        expect(server.row('movimientos', good2), isNotNull);
        expect(server.row('movimientos', bad), isNull);
        final rejected = (await device.queue()).single;
        expect(rejected.recordId, bad);
        expect(rejected.attempts, 1);
        expect(rejected.lastError, '23514');
        expect(
          rejected.nextAttemptAt,
          device.clock.now().toUtc().add(const Duration(minutes: 5)),
        );
        expect((await device.movement(bad))!.syncStatus, 'error');

        // Antes de su próximo intento no se vuelve a enviar.
        server.calls.clear();
        await device.sync();
        expect(upsertTables(), isEmpty);

        // Después sí; si sigue fallando, la espera crece.
        device.clock.advance(const Duration(minutes: 6));
        await device.sync();
        final again = (await device.queue()).single;
        expect(again.attempts, 2);
        expect(
          again.nextAttemptAt,
          device.clock.now().toUtc().add(const Duration(minutes: 10)),
        );

        // Cuando el servidor lo acepta, queda sincronizado.
        server.rejectedIds.clear();
        device.clock.advance(const Duration(minutes: 11));
        await device.sync();
        expect(await device.queue(), isEmpty);
        expect((await device.movement(bad))!.syncStatus, 'sincronizado');
      },
    );

    test(
      'editar un registro rechazado lo vuelve a enviar sin esperar',
      () async {
        final id = await device.addMovement(amount: 1);
        server.rejectedIds[id] = '23514';
        await device.sync();

        server.rejectedIds.clear();
        device.clock.advance(const Duration(seconds: 30));
        await device.editMovement(id, amount: 1500);
        await device.sync();

        expect(server.row('movimientos', id)!['monto'], 1500);
        expect(await device.queue(), isEmpty);
      },
    );

    test(
      'pushAll incluye los rechazados y devuelve lo que no se envió',
      () async {
        final id = await device.addMovement();
        server.rejectedIds[id] = '23514';
        await device.sync();

        expect(await device.service.pushAll(), 1);
        server.rejectedIds.clear();
        expect(await device.service.pushAll(), 0);
      },
    );

    test(
      'los registros que ya no existen salen de la cola sin enviarse',
      () async {
        final id = await device.addMovement();
        await device.db.delete(device.db.movements).go();
        await device.sync();
        expect(await device.queue(), isEmpty);
        expect(server.row('movimientos', id), isNull);
      },
    );
  });

  group('pull', () {
    test(
      'trae lo nuevo con paginación aunque compartan sincronizado_en',
      () async {
        // 450 filas de un mismo upsert: mismo sincronizado_en.
        final other = SyncDevice(server, idPrefix: 'z');
        addTearDown(other.close);
        for (var i = 0; i < 450; i++) {
          await other.addMovement(amount: 100 + i);
        }
        await other.sync();
        final syncedAt = server
            .rows('movimientos')
            .map((r) => r['sincronizado_en']);
        expect(syncedAt.toSet().length, lessThan(450));

        await device.sync();

        expect(await device.allMovements(), hasLength(450));
        final cursor = await LocalSyncStore(device.db).cursor('movimientos');
        expect(cursor, isNotNull);
        for (final row in await device.allMovements()) {
          expect(row.syncStatus, 'sincronizado');
        }
        expect(await device.queue(), isEmpty);
      },
    );

    test('ignora las categorías predeterminadas del servidor', () async {
      await device.sync();
      final names = (await device.db.select(device.db.categories).get()).map(
        (c) => c.name,
      );
      expect(names, hasLength(7));
      expect(await device.queue(), isEmpty);
    });

    test(
      'el solape recupera filas que confirmaron con un cursor anterior',
      () async {
        server.putRow('movimientos', remoteMovement('m-1'), userId: userA);
        await device.sync();
        final cursor = (await LocalSyncStore(device.db).cursor('movimientos'))!;

        // Una transacción larga que empezó antes confirma después.
        server.putRow(
          'movimientos',
          remoteMovement('m-tarde'),
          userId: userA,
          syncedAt: cursor.subtract(const Duration(minutes: 2)),
        );
        await device.sync();

        expect(await device.movement('m-tarde'), isNotNull);
      },
    );

    test('solo trae las filas del usuario (RLS)', () async {
      server.putRow('movimientos', remoteMovement('ajeno'), userId: userB);
      await device.sync();
      expect(await device.movement('ajeno'), isNull);
    });

    test('repetirlo no duplica ni escribe nada', () async {
      server.putRow('movimientos', remoteMovement('m-1'), userId: userA);
      await device.addMovement();
      await device.sync();
      final before = await device.allMovements();

      final writes = <TableUpdate>[];
      final subscription = device.db
          .tableUpdates(const TableUpdateQuery.any())
          .listen(writes.addAll);
      await device.sync();
      await device.sync();
      await pumpEventQueue();
      await subscription.cancel();

      expect(await device.allMovements(), before);
      expect(
        writes.where((u) => u.table != 'metadatos_sync'),
        isEmpty,
        reason: 'solo se reescribe el cursor',
      );
    });
  });

  group('conflictos', () {
    test('la local pendiente más nueva gana sobre la remota', () async {
      final id = await device.addMovement(amount: 1000);
      await device.sync();

      // Otro dispositivo editó antes (hora del dispositivo).
      server.putRow(
        'movimientos',
        remoteMovement(
          id,
          amount: 2000,
          updatedAt: device.clock.now().add(const Duration(minutes: 1)),
        ),
        userId: userA,
      );
      device.clock.advance(const Duration(minutes: 5));
      await device.editMovement(id, amount: 3000);

      await device.sync();

      expect((await device.movement(id))!.amount, 3000);
      expect(server.row('movimientos', id)!['monto'], 3000);
      expect(await device.queue(), isEmpty);
    });

    test('la remota más nueva gana y descarta la local pendiente', () async {
      final id = await device.addMovement(amount: 1000);
      await device.sync();
      device.clock.advance(const Duration(minutes: 1));
      await device.editMovement(id, amount: 3000);

      // Servidor con una versión posterior que este dispositivo no conoce.
      server.putRow(
        'movimientos',
        remoteMovement(
          id,
          amount: 2000,
          updatedAt: device.clock.now().add(const Duration(minutes: 10)),
        ),
        userId: userA,
      );

      await device.sync();

      // El push se ignoró en el servidor (versión más vieja) y el pull trajo
      // la más nueva.
      expect(server.row('movimientos', id)!['monto'], 2000);
      final row = (await device.movement(id))!;
      expect(row.amount, 2000);
      expect(row.syncStatus, 'sincronizado');
      expect(await device.queue(), isEmpty);
    });

    test(
      'la eliminación local prevalece sobre una edición remota más nueva',
      () async {
        final id = await device.addMovement();
        await device.sync();
        await device.deleteMovement(id);
        server.putRow(
          'movimientos',
          remoteMovement(
            id,
            amount: 7777,
            updatedAt: device.clock.now().add(const Duration(hours: 1)),
          ),
          userId: userA,
        );

        await device.sync();

        expect((await device.movement(id))!.deletedAt, isNotNull);
        expect(server.row('movimientos', id)!['eliminado_en'], isNotNull);
      },
    );

    test(
      'la eliminación remota prevalece sobre una edición local más nueva',
      () async {
        final id = await device.addMovement();
        await device.sync();
        device.clock.advance(const Duration(hours: 1));
        await device.editMovement(id, amount: 5555);
        // El servidor ya tiene la eliminación (de otro dispositivo, más vieja).
        server.putRow(
          'movimientos',
          remoteMovement(
            id,
            updatedAt: device.clock.now().subtract(const Duration(minutes: 30)),
            deletedAt: device.clock.now().subtract(const Duration(minutes: 30)),
          ),
          userId: userA,
        );

        await device.sync();

        final row = (await device.movement(id))!;
        expect(row.deletedAt, isNotNull);
        expect(row.syncStatus, 'sincronizado');
        expect(server.row('movimientos', id)!['eliminado_en'], isNotNull);
        expect(await device.queue(), isEmpty);
      },
    );

    test('un eliminado que llega del servidor queda como lápida', () async {
      server.putRow(
        'movimientos',
        remoteMovement('borrado', deletedAt: DateTime.utc(2026, 9, 21)),
        userId: userA,
      );
      await device.sync();
      expect((await device.movement('borrado'))!.deletedAt, isNotNull);
    });
  });

  group('recibos', () {
    test('la ruta local nunca se sobrescribe desde el servidor', () async {
      final movementId = await device.addMovement(
        receipt: (movementId) => Receipt(
          id: 'r-1',
          movementId: movementId,
          localPath: 'recibos/r-1.jpg',
          detectedMerchant: 'Éxito',
        ),
      );
      await device.sync();

      final remote = server.row('recibos', 'r-1')!
        ..['comercio_detectado'] = 'Carulla'
        ..['actualizado_en'] = DateTime.utc(2026, 9, 23).toIso8601String();
      remote.remove('sincronizado_en');
      server.putRow('recibos', remote, userId: userA);
      await device.sync();

      final receipt = await (device.db.select(
        device.db.receipts,
      )..where((t) => t.id.equals('r-1'))).getSingle();
      expect(receipt.detectedMerchant, 'Carulla');
      expect(receipt.localPath, 'recibos/r-1.jpg');
      expect(receipt.movementId, movementId);
    });

    test('un recibo que llega de otro dispositivo no trae imagen', () async {
      server.putRow('movimientos', remoteMovement('m-1'), userId: userA);
      server.putRow('recibos', {
        'id': 'r-9',
        'movimiento_id': 'm-1',
        'ruta_storage': null,
        'total_detectado': 5000,
        'comercio_detectado': null,
        'creado_en': '2026-09-21T12:00:00.000Z',
        'actualizado_en': '2026-09-21T12:00:00.000Z',
        'eliminado_en': null,
      }, userId: userA);

      await device.sync();

      final receipt = await device.db.select(device.db.receipts).getSingle();
      expect(receipt.id, 'r-9');
      expect(receipt.localPath, isNull);
    });
  });

  group('una sola sincronización a la vez', () {
    test(
      'las solicitudes durante una ejecución esperan una sola más',
      () async {
        await device.addMovement();
        final gate = Completer<void>();
        server.onUpsert = (_, _) => gate.future;

        final first = device.sync();
        await pumpEventQueue();
        final second = device.sync();
        final third = device.sync();
        expect(identical(second, third), isTrue);

        gate.complete();
        await Future.wait([first, second, third]);

        final selects = server.calls.where(
          (c) => c.method == 'select' && c.table == 'categorias',
        );
        expect(selects, hasLength(2));
      },
    );

    test('después de shutdown no sincroniza', () async {
      await device.addMovement();
      await device.service.shutdown();
      expect(await device.sync(), SyncResult.skipped);
      expect(server.calls, isEmpty);
    });
  });

  test('rejectedRetryDelay crece hasta 24 h', () {
    expect(rejectedRetryDelay(1), const Duration(minutes: 5));
    expect(rejectedRetryDelay(2), const Duration(minutes: 10));
    expect(rejectedRetryDelay(3), const Duration(minutes: 20));
    expect(rejectedRetryDelay(20), const Duration(hours: 24));
  });
}
