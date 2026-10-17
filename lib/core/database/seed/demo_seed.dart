import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/budgets/data/budgets_providers.dart';
import '../../../features/budgets/domain/entities/budget.dart';
import '../../../features/budgets/domain/entities/default_categories.dart';
import '../../../features/budgets/domain/repositories/budget_repository.dart';
import '../../../features/movements/data/movements_providers.dart';
import '../../../features/movements/domain/entities/movement.dart';
import '../../../features/movements/domain/repositories/movement_repository.dart';
import '../../../features/onboarding/data/onboarding_providers.dart';
import '../../../features/onboarding/domain/onboarding_repository.dart';
import '../../sync/sync_status.dart';
import '../../utils/clock.dart';
import '../../utils/id_generator.dart';
import '../../utils/utils_providers.dart';
import '../app_database.dart';
import '../database_providers.dart';

// Datos de demostración. Solo se ofrecen en modo desarrollo (kDebugMode): en
// la versión de publicación la app arranca vacía.
//
// Las fechas son relativas al reloj para que la demo funcione en cualquier
// fecha. Con el 22 de septiembre de 2026 como "hoy":
// - Septiembre: ingresos $4.250.000; gastos $2.375.680 (Mercado 897.000,
//   Transporte 427.600, Ocio 522.650, Servicios 308.840, Otros 219.590).
// - Agosto: ingresos $2.615.600; gastos $2.195.600.
// - Junio y julio: ingresos $4.250.000 y gastos $3.830.000 cada uno.
// - Ahorro promedio de junio a agosto: $420.000.
// - Presupuesto de Mercado de septiembre: $1.150.000 (queda en 78%).

/// Presupuesto de Mercado del mes actual en la demo.
const int demoMercadoBudget = 1150000;

// Días especiales del mes actual; los demás valores son el día del mes.
const int _today = 0;
const int _yesterday = -1;

/// Movimiento de la demo antes de convertirse en [Movement].
class _DemoEntry {
  const _DemoEntry(
    this.monthsAgo,
    this.day,
    this.description,
    this.category,
    this.amount,
  );

  /// 0 es el mes actual; 1, el anterior.
  final int monthsAgo;

  /// Día del mes, [_today] o [_yesterday]. En meses anteriores, como máximo 28.
  final int day;
  final String description;
  final DefaultCategory category;
  final int amount;
}

const _mercado = DefaultCategory.mercado;
const _transporte = DefaultCategory.transporte;
const _ocio = DefaultCategory.ocio;
const _servicios = DefaultCategory.servicios;
const _restaurantes = DefaultCategory.restaurantes;
const _otros = DefaultCategory.otros;
const _ingreso = DefaultCategory.ingreso;

/// Movimientos de la demo, del más reciente al más antiguo dentro de cada mes.
/// El orden define también el momento de creación: en un mismo día aparece
/// primero el que está antes en la lista.
const List<_DemoEntry> _entries = [
  // Mes actual: los movimientos de la Fase 3 y otros del mes.
  _DemoEntry(0, _today, 'Éxito', _mercado, 87400),
  _DemoEntry(0, _yesterday, 'TransMilenio', _transporte, 5600),
  _DemoEntry(0, 20, 'Uber', _transporte, 38500),
  _DemoEntry(0, 19, 'Bar El Chorro', _ocio, 98350),
  _DemoEntry(0, 18, 'D1', _mercado, 98700),
  _DemoEntry(0, 17, 'Taxi', _transporte, 23500),
  _DemoEntry(0, 16, 'Papelería', _otros, 52000),
  _DemoEntry(0, 15, 'Carulla', _mercado, 245300),
  _DemoEntry(0, 14, 'Regalo de cumpleaños', _otros, 120000),
  _DemoEntry(0, 13, 'Cine Colombia', _ocio, 64000),
  _DemoEntry(0, 12, 'Gasolina Terpel', _transporte, 180000),
  _DemoEntry(0, 11, 'Farmacia', _otros, 47590),
  _DemoEntry(0, 10, 'Concierto', _ocio, 280000),
  _DemoEntry(0, 9, 'Peaje', _transporte, 80000),
  _DemoEntry(0, 8, 'Éxito', _mercado, 312400),
  _DemoEntry(0, 7, 'Acueducto', _servicios, 78500),
  _DemoEntry(0, 7, 'Gas natural', _servicios, 37900),
  _DemoEntry(0, 6, 'Energía', _servicios, 112340),
  _DemoEntry(0, 5, 'Netflix', _ocio, 44900),
  _DemoEntry(0, 5, 'Spotify', _ocio, 16900),
  _DemoEntry(0, 4, 'Internet', _servicios, 80100),
  _DemoEntry(0, 3, 'Ara', _mercado, 153200),
  _DemoEntry(0, 2, 'Recarga TuLlave', _transporte, 100000),
  _DemoEntry(0, 1, 'Salario', _ingreso, 3800000),
  _DemoEntry(0, 1, 'Juan Valdez', _ocio, 18500),
  _DemoEntry(0, 1, 'Freelance', _ingreso, 450000),

  // Mes anterior.
  _DemoEntry(1, 25, 'Peluquería', _otros, 120000),
  _DemoEntry(1, 23, 'Paseo de fin de semana', _ocio, 300000),
  _DemoEntry(1, 22, 'Uber', _transporte, 144800),
  _DemoEntry(1, 20, 'Freelance', _ingreso, 315600),
  _DemoEntry(1, 19, 'Carulla', _mercado, 381000),
  _DemoEntry(1, 16, 'Cine Colombia', _ocio, 99000),
  _DemoEntry(1, 12, 'Farmacia', _otros, 89100),
  _DemoEntry(1, 10, 'Acueducto', _servicios, 120000),
  _DemoEntry(1, 8, 'Gasolina Terpel', _transporte, 220000),
  _DemoEntry(1, 6, 'Energía', _servicios, 121700),
  _DemoEntry(1, 5, 'Éxito', _mercado, 420000),
  _DemoEntry(1, 4, 'Internet', _servicios, 80000),
  _DemoEntry(1, 3, 'Recarga TuLlave', _transporte, 100000),
  _DemoEntry(1, 1, 'Salario', _ingreso, 2300000),

  // Dos meses antes.
  _DemoEntry(2, 26, 'Cena de cumpleaños', _restaurantes, 300000),
  _DemoEntry(2, 25, 'Bolera', _ocio, 330000),
  _DemoEntry(2, 19, 'D1', _mercado, 500000),
  _DemoEntry(2, 15, 'Freelance', _ingreso, 450000),
  _DemoEntry(2, 15, 'Cita médica', _otros, 300000),
  _DemoEntry(2, 12, 'Concierto', _ocio, 450000),
  _DemoEntry(2, 11, 'Wok', _restaurantes, 210000),
  _DemoEntry(2, 10, 'Gasolina Terpel', _transporte, 380000),
  _DemoEntry(2, 8, 'Acueducto', _servicios, 135000),
  _DemoEntry(2, 6, 'Energía', _servicios, 175000),
  _DemoEntry(2, 4, 'Éxito', _mercado, 650000),
  _DemoEntry(2, 4, 'Internet', _servicios, 160000),
  _DemoEntry(2, 2, 'Recarga TuLlave', _transporte, 240000),
  _DemoEntry(2, 1, 'Salario', _ingreso, 3800000),

  // Tres meses antes.
  _DemoEntry(3, 27, 'Cine Colombia', _ocio, 150000),
  _DemoEntry(3, 21, 'Andrés Carne de Res', _restaurantes, 280000),
  _DemoEntry(3, 20, 'Carulla', _mercado, 500000),
  _DemoEntry(3, 18, 'Ropa', _otros, 300000),
  _DemoEntry(3, 15, 'Freelance', _ingreso, 450000),
  _DemoEntry(3, 14, 'Viaje a Villa de Leyva', _ocio, 550000),
  _DemoEntry(3, 13, 'Crepes & Waffles', _restaurantes, 220000),
  _DemoEntry(3, 9, 'Gasolina Terpel', _transporte, 400000),
  _DemoEntry(3, 8, 'Acueducto', _servicios, 140000),
  _DemoEntry(3, 6, 'Éxito', _mercado, 700000),
  _DemoEntry(3, 6, 'Energía', _servicios, 180000),
  _DemoEntry(3, 4, 'Internet', _servicios, 160000),
  _DemoEntry(3, 2, 'Recarga TuLlave', _transporte, 250000),
  _DemoEntry(3, 1, 'Salario', _ingreso, 3800000),
];

/// Fecha de [entry] según "hoy" ([now]). En el mes actual, "ayer" se ajusta al
/// día 1 si cae en el mes anterior, y los demás días quedan antes de "ayer"
/// (o en el día 1) para no pasar a "hoy" ni al futuro.
DateTime _dateOf(_DemoEntry entry, DateTime now) {
  final today = dateOnly(now);
  if (entry.monthsAgo > 0) {
    return DateTime(today.year, today.month - entry.monthsAgo, entry.day);
  }
  return switch (entry.day) {
    _today => today,
    _yesterday => DateTime(
      today.year,
      today.month,
      today.day > 1 ? today.day - 1 : 1,
    ),
    final day => DateTime(
      today.year,
      today.month,
      day.clamp(1, today.day > 2 ? today.day - 2 : 1),
    ),
  };
}

/// Movimientos de la demo con fechas relativas a [clock], del más reciente al
/// más antiguo. Función pura (los identificadores salen de [ids]).
List<Movement> buildDemoMovements({
  required Clock clock,
  required IdGenerator ids,
}) {
  final now = clock.now();
  return [
    for (var i = 0; i < _entries.length; i++)
      Movement(
        id: ids.newId(),
        type: _entries[i].category.type,
        amount: _entries[i].amount,
        date: _dateOf(_entries[i], now),
        categoryId: _entries[i].category.id,
        description: _entries[i].description,
        origin: MovementOrigin.manual,
        // Creados un segundo antes que el anterior de la lista, y antes de
        // "ahora" para que lo que se registre después quede arriba.
        createdAt: now.subtract(Duration(seconds: i + 1)),
        updatedAt: now.subtract(Duration(seconds: i + 1)),
        syncStatus: SyncStatus.pending,
      ),
  ];
}

/// Carga y borra los datos de demostración. Inserta con los repositorios, así
/// que todo pasa por la cola de sincronización como cualquier dato.
class DemoSeed {
  const DemoSeed({
    required this._db,
    required this._movements,
    required this._budgets,
    required this._onboarding,
    required this._clock,
    required this._ids,
  });

  final AppDatabase _db;
  final MovementRepository _movements;
  final BudgetRepository _budgets;
  final OnboardingRepository _onboarding;
  final Clock _clock;
  final IdGenerator _ids;

  /// Reemplaza todos los datos por los de la demo. También marca la bienvenida
  /// como completada: con la demo no se muestra ni duplica ingresos.
  Future<void> load() {
    return _db.transaction(() async {
      await clearAll();
      for (final movement in buildDemoMovements(clock: _clock, ids: _ids)) {
        await _movements.add(movement);
      }
      await _budgets.save(
        Budget(
          id: _ids.newId(),
          categoryId: DefaultCategory.mercado.id,
          month: _clock.currentMonth(),
          limitAmount: demoMercadoBudget,
        ),
        at: _clock.now(),
      );
      await _onboarding.markWelcomeDone();
    });
  }

  /// Borra todos los datos del usuario, incluida la cola de sincronización.
  /// Conserva las categorías predeterminadas y la marca de la bienvenida.
  Future<void> clearAll() {
    return _db.transaction(() async {
      // Primero los que tienen llaves foráneas.
      await _db.delete(_db.receipts).go();
      await _db.delete(_db.movements).go();
      await _db.delete(_db.budgets).go();
      await (_db.delete(_db.categories)..where(
            (t) => t.id.isNotIn([for (final c in DefaultCategory.values) c.id]),
          ))
          .go();
      await _db.delete(_db.syncQueue).go();
      await _db.delete(_db.syncMetadata).go();
    });
  }
}

final demoSeedProvider = Provider<DemoSeed>(
  (ref) => DemoSeed(
    db: ref.watch(appDatabaseProvider),
    movements: ref.watch(movementRepositoryProvider),
    budgets: ref.watch(budgetRepositoryProvider),
    onboarding: ref.watch(onboardingRepositoryProvider),
    clock: ref.watch(clockProvider),
    ids: ref.watch(idGeneratorProvider),
  ),
);

/// Muestra las acciones de datos de demostración. Solo en modo desarrollo; las
/// pruebas lo sobrescriben para simular la versión de publicación.
final demoToolsEnabledProvider = Provider<bool>((ref) => kDebugMode);
