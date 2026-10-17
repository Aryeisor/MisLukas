import 'package:mislukas/core/database/app_database.dart';
import 'package:mislukas/core/sync/local_sync_store.dart';
import 'package:mislukas/core/sync/sync_service.dart';
import 'package:mislukas/features/budgets/data/drift_budget_repository.dart';
import 'package:mislukas/features/budgets/domain/entities/budget.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';
import 'package:mislukas/features/movements/data/drift_movement_repository.dart';
import 'package:mislukas/features/movements/domain/entities/movement.dart';
import 'package:mislukas/features/movements/domain/entities/receipt.dart';

import 'fake_sync_server.dart';
import 'test_database.dart';

/// Usuarios de las pruebas de sincronización.
const String userA = '00000000-0000-4000-8000-00000000000a';
const String userB = '00000000-0000-4000-8000-00000000000b';

/// Un dispositivo: base en memoria, repositorios reales y servicio de
/// sincronización contra el servidor falso.
class SyncDevice {
  SyncDevice(
    this.server, {
    this.userId = userA,
    String idPrefix = 'a',
    MutableClock? clock,
  }) : db = openTestDatabase(),
       ids = PrefixedIdGenerator(idPrefix),
       clock = clock ?? MutableClock(DateTime(2026, 9, 22, 10, 30)) {
    movements = DriftMovementRepository(db);
    budgets = DriftBudgetRepository(db);
    service = SyncService(
      store: LocalSyncStore(db),
      remote: server.sourceFor(userId),
      clock: this.clock,
    );
  }

  final FakeSyncServer server;
  final String userId;
  final AppDatabase db;
  final PrefixedIdGenerator ids;
  final MutableClock clock;
  late final DriftMovementRepository movements;
  late final DriftBudgetRepository budgets;
  late final SyncService service;

  Future<SyncResult> sync() => service.run();

  Future<String> addMovement({
    int amount = 10000,
    String description = 'Prueba',
    DefaultCategory category = DefaultCategory.mercado,
    Receipt Function(String movementId)? receipt,
  }) async {
    final now = clock.now();
    final id = ids.newId();
    await movements.add(
      Movement(
        id: id,
        type: category.type,
        amount: amount,
        date: DateTime(2026, 9, 20),
        categoryId: category.id,
        description: description,
        origin: MovementOrigin.manual,
        createdAt: now,
        updatedAt: now,
      ),
      receipt: receipt?.call(id),
    );
    return id;
  }

  Future<void> editMovement(String id, {required int amount}) async {
    final current = (await movements.findById(id))!;
    await movements.update(
      current.copyWith(amount: amount, updatedAt: clock.now()),
    );
  }

  Future<void> deleteMovement(String id) =>
      movements.softDelete(id, at: clock.now());

  Future<String> saveBudget(int limit, {DateTime? month}) async {
    final saved = await budgets.save(
      Budget(
        id: ids.newId(),
        categoryId: DefaultCategory.mercado.id,
        month: month ?? DateTime(2026, 9),
        limitAmount: limit,
      ),
      at: clock.now(),
    );
    return saved.id;
  }

  Future<MovementRow?> movement(String id) => (db.select(
    db.movements,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<MovementRow>> allMovements() => db.select(db.movements).get();

  Future<List<BudgetRow>> activeBudgets() =>
      (db.select(db.budgets)..where((t) => t.deletedAt.isNull())).get();

  Future<List<SyncQueueEntry>> queue() => db.select(db.syncQueue).get();

  Future<void> close() => db.close();
}
