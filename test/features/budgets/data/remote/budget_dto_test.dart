import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/database/app_database.dart';
import 'package:mislukas/features/budgets/data/remote/budget_dto.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';

import '../../../../helpers/test_database.dart';

Map<String, dynamic> overTheWire(Map<String, dynamic> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  test('ida y vuelta local → remoto → local conserva la fila', () async {
    final at = DateTime.utc(2026, 9, 22, 14, 30, 5, 123, 456);
    await db
        .into(db.budgets)
        .insert(
          BudgetsCompanion.insert(
            id: 'b1',
            categoryId: DefaultCategory.ocio.id,
            month: DateTime(2026, 9),
            limitAmount: 300000,
            createdAt: at,
            updatedAt: at,
            deletedAt: Value(at),
          ),
        );
    final original = await db.select(db.budgets).getSingle();

    final json = overTheWire(BudgetDto.fromRow(original).toJson());
    expect(json['mes'], '2026-09-01');
    expect(json['monto_limite'], 300000);
    expect(json.containsKey('usuario_id'), isFalse);
    expect(json.containsKey('sincronizado_en'), isFalse);

    await db.delete(db.budgets).go();
    await db.into(db.budgets).insert(BudgetDto.fromJson(json).toCompanion());

    expect(
      await db.select(db.budgets).getSingle(),
      original.copyWith(syncStatus: 'sincronizado'),
    );
  });

  test('lee el formato de PostgREST', () {
    final dto = BudgetDto.fromJson({
      'id': 'b1',
      'usuario_id': 'u1',
      'categoria_id': DefaultCategory.mercado.id,
      'mes': '2026-10-01',
      'monto_limite': 800000,
      'creado_en': '2026-10-01T05:00:00+00:00',
      'actualizado_en': '2026-10-01T00:00:00-05:00',
      'eliminado_en': null,
      'sincronizado_en': '2026-10-01T05:00:00.25+00:00',
    });

    expect(dto.month, DateTime(2026, 10));
    expect(dto.limitAmount, 800000);
    expect(dto.updatedAt, DateTime.utc(2026, 10, 1, 5));
    expect(dto.deletedAt, isNull);
  });

  test('rechaza un límite con decimales', () {
    expect(
      () => BudgetDto.fromJson({
        'id': 'b1',
        'categoria_id': DefaultCategory.mercado.id,
        'mes': '2026-10-01',
        'monto_limite': 800000.0,
        'creado_en': '2026-10-01T05:00:00+00:00',
        'actualizado_en': '2026-10-01T05:00:00+00:00',
      }),
      throwsFormatException,
    );
  });
}
