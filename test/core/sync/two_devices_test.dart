import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/database/seed/demo_seed.dart';
import 'package:mislukas/core/sync/sync_service.dart';
import 'package:mislukas/features/budgets/data/drift_budget_repository.dart';
import 'package:mislukas/features/movements/data/drift_movement_repository.dart';

import '../../helpers/fake_sync_server.dart';
import '../../helpers/sync_device.dart';

/// Dos bases en memoria (celular y emulador) del mismo usuario contra el
/// mismo servidor falso.
void main() {
  late FakeSyncServer server;
  late SyncDevice phone;
  late SyncDevice emulator;

  setUp(() {
    server = FakeSyncServer();
    phone = SyncDevice(server, idPrefix: 'a');
    emulator = SyncDevice(server, idPrefix: 'b');
  });
  tearDown(() async {
    await phone.close();
    await emulator.close();
  });

  test('lo creado, editado y eliminado en uno aparece en el otro', () async {
    final id = await phone.addMovement(amount: 25000, description: 'Taxi');
    await phone.sync();
    await emulator.sync();

    var row = (await emulator.movement(id))!;
    expect(row.amount, 25000);
    expect(row.description, 'Taxi');
    expect(row.syncStatus, 'sincronizado');

    phone.clock.advance(const Duration(minutes: 1));
    await phone.editMovement(id, amount: 30000);
    await phone.sync();
    await emulator.sync();
    expect((await emulator.movement(id))!.amount, 30000);

    phone.clock.advance(const Duration(minutes: 1));
    await phone.deleteMovement(id);
    await phone.sync();
    await emulator.sync();
    row = (await emulator.movement(id))!;
    expect(row.deletedAt, isNotNull);
    expect(await emulator.movements.findById(id), isNull);

    // Y de vuelta: lo creado en el emulador llega al celular.
    final other = await emulator.addMovement(description: 'Mercado');
    await emulator.sync();
    await phone.sync();
    expect((await phone.movement(other))!.description, 'Mercado');
  });

  test('ediciones sin conexión en los dos: gana la más reciente aunque la más '
      'vieja se envíe después', () async {
    final id = await phone.addMovement(amount: 1000);
    await phone.sync();
    await emulator.sync();

    // El celular edita sin conexión a las 10:31.
    server.offline = true;
    phone.clock.advance(const Duration(minutes: 1));
    await phone.editMovement(id, amount: 2000);
    expect(await phone.sync(), SyncResult.offline);
    server.offline = false;

    // El emulador edita a las 10:35 y sincroniza primero.
    emulator.clock.advance(const Duration(minutes: 5));
    await emulator.editMovement(id, amount: 3000);
    await emulator.sync();

    // El celular recupera la conexión: su versión es más vieja.
    await phone.sync();
    await emulator.sync();

    expect(server.row('movimientos', id)!['monto'], 3000);
    expect((await phone.movement(id))!.amount, 3000);
    expect((await emulator.movement(id))!.amount, 3000);
    expect(await phone.queue(), isEmpty);
    expect(await emulator.queue(), isEmpty);
  });

  test(
    'la edición más reciente sin conexión gana cuando se envía después',
    () async {
      final id = await phone.addMovement(amount: 1000);
      await phone.sync();
      await emulator.sync();

      emulator.clock.advance(const Duration(minutes: 1));
      await emulator.editMovement(id, amount: 2000);
      await emulator.sync();

      // El celular editó más tarde, sin conexión, y sincroniza después.
      phone.clock.advance(const Duration(minutes: 9));
      await phone.editMovement(id, amount: 9000);
      await phone.sync();
      await emulator.sync();

      expect((await phone.movement(id))!.amount, 9000);
      expect((await emulator.movement(id))!.amount, 9000);
    },
  );

  test('eliminar en uno y editar en el otro: queda eliminado en los dos', () async {
    final id = await phone.addMovement(amount: 1000);
    await phone.sync();
    await emulator.sync();

    // El celular elimina sin conexión; el emulador edita después y sincroniza.
    phone.clock.advance(const Duration(minutes: 1));
    await phone.deleteMovement(id);
    emulator.clock.advance(const Duration(minutes: 30));
    await emulator.editMovement(id, amount: 5000);
    await emulator.sync();

    await phone.sync();
    await emulator.sync();

    expect((await phone.movement(id))!.deletedAt, isNotNull);
    expect((await emulator.movement(id))!.deletedAt, isNotNull);
    expect(server.row('movimientos', id)!['eliminado_en'], isNotNull);
    expect(await phone.queue(), isEmpty);
    expect(await emulator.queue(), isEmpty);
  });

  test(
    'un presupuesto de la misma categoría y mes en los dos queda uno solo',
    () async {
      await phone.saveBudget(800000);
      await phone.sync();

      // El emulador creó el suyo más tarde, sin haber recibido el del celular.
      emulator.clock.advance(const Duration(minutes: 3));
      final newer = await emulator.saveBudget(950000);
      await emulator.sync();
      await phone.sync();
      await emulator.sync();

      final serverActive = server
          .rows('presupuestos')
          .where((r) => r['eliminado_en'] == null)
          .toList();
      expect(serverActive.single['id'], newer);
      expect(serverActive.single['monto_limite'], 950000);
      for (final device in [phone, emulator]) {
        final active = await device.activeBudgets();
        expect(active.single.id, newer, reason: device.ids.prefix);
        expect(await device.queue(), isEmpty, reason: device.ids.prefix);
      }
    },
  );

  test(
    'datos de demostración en los dos: sin presupuestos duplicados',
    () async {
      for (final device in [phone, emulator]) {
        await DemoSeed(
          db: device.db,
          movements: DriftMovementRepository(device.db),
          budgets: DriftBudgetRepository(device.db),
          clock: device.clock,
          ids: device.ids,
        ).load();
      }

      await phone.sync();
      await emulator.sync();
      await phone.sync();

      final phoneMovements = await phone.allMovements();
      final emulatorMovements = await emulator.allMovements();
      // Cada demo tiene sus propios ids: son movimientos distintos.
      expect(phoneMovements, hasLength(2 * 68));
      expect(emulatorMovements.length, phoneMovements.length);
      expect((await phone.activeBudgets()), hasLength(1));
      expect((await emulator.activeBudgets()), hasLength(1));
      expect(
        (await phone.activeBudgets()).single.id,
        (await emulator.activeBudgets()).single.id,
      );
    },
  );
}
