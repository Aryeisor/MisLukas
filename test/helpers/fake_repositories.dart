import 'dart:async';

import 'package:mislukas/features/budgets/domain/entities/budget.dart';
import 'package:mislukas/features/budgets/domain/entities/category.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';
import 'package:mislukas/features/budgets/domain/repositories/budget_repository.dart';
import 'package:mislukas/features/budgets/domain/repositories/category_repository.dart';
import 'package:mislukas/core/utils/clock.dart';
import 'package:mislukas/features/movements/domain/entities/month_summary.dart';
import 'package:mislukas/features/movements/domain/entities/movement.dart';
import 'package:mislukas/features/movements/domain/entities/movement_filter.dart';
import 'package:mislukas/features/movements/domain/entities/receipt.dart';
import 'package:mislukas/features/movements/domain/repositories/movement_repository.dart';

// Repositorios en memoria para probar los casos de uso sin base de datos.

/// Stream que emite el valor actual y vuelve a emitir con cada cambio.
Stream<T> _watch<T>(Stream<void> changes, T Function() read) {
  return Stream.multi((controller) {
    controller.add(read());
    final subscription = changes.listen((_) => controller.add(read()));
    controller.onCancel = subscription.cancel;
  });
}

class FakeMovementRepository implements MovementRepository {
  FakeMovementRepository([Iterable<Movement> initial = const []]) {
    for (final movement in initial) {
      _items[movement.id] = movement;
    }
  }

  final Map<String, Movement> _items = {};
  final Map<String, Receipt> receipts = {};
  final StreamController<void> _changes = StreamController.broadcast();

  /// Todos los movimientos, incluidos los eliminados.
  List<Movement> get all => _items.values.toList();

  List<Movement> get _active =>
      _items.values.where((m) => !m.isDeleted).toList()..sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
      });

  @override
  Future<void> add(Movement movement, {Receipt? receipt}) async {
    _items[movement.id] = movement;
    if (receipt != null) receipts[receipt.id] = receipt;
    _changes.add(null);
  }

  @override
  Future<void> update(Movement movement) async {
    _items[movement.id] = movement;
    _changes.add(null);
  }

  @override
  Future<void> softDelete(String id, {required DateTime at}) async {
    _items[id] = _items[id]!.copyWith(deletedAt: () => at, updatedAt: at);
    _changes.add(null);
  }

  @override
  Future<Movement?> findById(String id) async {
    final movement = _items[id];
    return movement == null || movement.isDeleted ? null : movement;
  }

  @override
  Stream<List<Movement>> watchRecent({required int limit}) =>
      _watch(_changes.stream, () => _active.take(limit).toList());

  @override
  Stream<List<Movement>> watchBetween(
    DateTime from,
    DateTime to, {
    MovementFilter filter = MovementFilter.all,
  }) => _watch(
    _changes.stream,
    () => _between(from, to).where(filter.matches).toList(),
  );

  @override
  Stream<List<MonthSummary>> watchMonthSummaries({
    MovementFilter filter = MovementFilter.all,
  }) => _watch(_changes.stream, () {
    final byMonth = <DateTime, List<Movement>>{};
    for (final movement in _active.where(filter.matches)) {
      byMonth.putIfAbsent(monthStart(movement.date), () => []).add(movement);
    }
    final months = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final month in months)
        summarizeMonth(month: month, movements: byMonth[month]!),
    ];
  });

  @override
  Future<List<Movement>> getBetween(DateTime from, DateTime to) async =>
      _between(from, to);

  List<Movement> _between(DateTime from, DateTime to) => _active
      .where((m) => !m.date.isBefore(from) && m.date.isBefore(to))
      .toList();
}

class FakeCategoryRepository implements CategoryRepository {
  FakeCategoryRepository([List<Category>? categories])
    : _categories =
          categories ??
          [for (final c in DefaultCategory.values) c.toCategory()];

  final List<Category> _categories;

  @override
  Stream<List<Category>> watchAll() => Stream.value(_categories);

  @override
  Future<List<Category>> getAll() async => _categories;

  @override
  Future<Category?> findById(String id) async {
    for (final category in _categories) {
      if (category.id == id) return category;
    }
    return null;
  }
}

class FakeBudgetRepository implements BudgetRepository {
  FakeBudgetRepository([Iterable<Budget> initial = const []]) {
    budgets.addAll(initial);
  }

  /// Presupuestos activos.
  final List<Budget> budgets = [];

  /// Presupuestos quitados (borrado lógico).
  final List<Budget> removed = [];
  final StreamController<void> _changes = StreamController.broadcast();

  List<Budget> _forMonth(DateTime month) =>
      budgets.where((b) => b.month == month).toList();

  @override
  Stream<List<Budget>> watchForMonth(DateTime month) =>
      _watch(_changes.stream, () => _forMonth(month));

  @override
  Future<List<Budget>> getForMonth(DateTime month) async => _forMonth(month);

  @override
  Future<Budget?> findById(String id) async {
    for (final budget in budgets) {
      if (budget.id == id) return budget;
    }
    return null;
  }

  @override
  Future<Budget> save(Budget budget, {required DateTime at}) async {
    final index = budgets.indexWhere(
      (b) => b.categoryId == budget.categoryId && b.month == budget.month,
    );
    final saved = index < 0
        ? budget
        : Budget(
            id: budgets[index].id,
            categoryId: budget.categoryId,
            month: budget.month,
            limitAmount: budget.limitAmount,
          );
    if (index < 0) {
      budgets.add(saved);
    } else {
      budgets[index] = saved;
    }
    _changes.add(null);
    return saved;
  }

  @override
  Future<void> remove(String id, {required DateTime at}) async {
    final index = budgets.indexWhere((b) => b.id == id);
    if (index < 0) throw StateError('Presupuesto inexistente: $id');
    removed.add(budgets.removeAt(index));
    _changes.add(null);
  }

  @override
  Future<List<Budget>> carryOver({
    required DateTime month,
    required DateTime at,
    required String Function() newId,
  }) async {
    final all = [...budgets, ...removed];
    if (all.any((b) => b.month == month)) return const [];
    final earlier = [
      for (final b in all)
        if (b.month.isBefore(month)) b.month,
    ];
    if (earlier.isEmpty) return const [];
    final source = earlier.reduce((a, b) => a.isAfter(b) ? a : b);
    final copies = [
      for (final b in _forMonth(source))
        Budget(
          id: newId(),
          categoryId: b.categoryId,
          month: month,
          limitAmount: b.limitAmount,
        ),
    ];
    budgets.addAll(copies);
    if (copies.isNotEmpty) _changes.add(null);
    return copies;
  }
}
