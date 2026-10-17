import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/database/app_database.dart';
import 'package:mislukas/features/budgets/data/remote/category_dto.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';
import 'package:mislukas/features/movements/domain/entities/movement.dart';

import '../../../../helpers/test_database.dart';

Map<String, dynamic> overTheWire(Map<String, dynamic> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  test('ida y vuelta de una categoría personalizada', () async {
    final at = DateTime.utc(2026, 9, 22, 14, 30, 5, 123, 456);
    await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            id: 'c1',
            name: 'Mascotas',
            type: 'gasto',
            icon: const Value('mascotas'),
            color: const Value('#0EA5E9'),
            createdAt: at,
            updatedAt: at,
          ),
        );
    final original = await (db.select(
      db.categories,
    )..where((t) => t.id.equals('c1'))).getSingle();

    final json = overTheWire(CategoryDto.fromRow(original).toJson());
    expect(json.containsKey('usuario_id'), isFalse);
    expect(json.containsKey('sincronizado_en'), isFalse);

    await (db.delete(db.categories)..where((t) => t.id.equals('c1'))).go();
    await db
        .into(db.categories)
        .insert(CategoryDto.fromJson(json).toCompanion());

    expect(
      await (db.select(
        db.categories,
      )..where((t) => t.id.equals('c1'))).getSingle(),
      original.copyWith(syncStatus: 'sincronizado'),
    );
  });

  test('una fila sin usuario_id es predeterminada', () {
    final dto = CategoryDto.fromJson({
      'id': DefaultCategory.ingreso.id,
      'usuario_id': null,
      'nombre': 'Ingreso',
      'tipo': 'ingreso',
      'icono': 'ingreso',
      'color': null,
      'creado_en': '2026-01-01T00:00:00+00:00',
      'actualizado_en': '2026-01-01T00:00:00+00:00',
      'eliminado_en': null,
      'sincronizado_en': '2026-10-16T15:00:00+00:00',
    });

    expect(dto.isDefault, isTrue);
    expect(dto.type, MovementType.income);
    expect(dto.createdAt, defaultCategoriesCreatedAt);
  });

  test('las predeterminadas locales coinciden con las del servidor', () async {
    // Lo que inserta supabase/migrations/002 debe ser igual a lo local.
    final rows = await db.select(db.categories).get();
    for (final row in rows) {
      final json = CategoryDto.fromRow(row).toJson();
      expect(json['creado_en'], '2026-01-01T00:00:00.000Z');
      expect(json['icono'], DefaultCategory.fromId(row.id)!.key);
    }
  });

  test('una fila con dueño es personalizada', () {
    final dto = CategoryDto.fromJson({
      'id': 'c1',
      'usuario_id': 'u1',
      'nombre': 'Mascotas',
      'tipo': 'gasto',
      'creado_en': '2026-09-22T00:00:00+00:00',
      'actualizado_en': '2026-09-22T00:00:00+00:00',
    });
    expect(dto.isDefault, isFalse);
  });

  test('rechaza un tipo desconocido', () {
    expect(
      () => CategoryDto.fromJson({
        'id': 'c1',
        'nombre': 'x',
        'tipo': 'ahorro',
        'creado_en': '2026-09-22T00:00:00+00:00',
        'actualizado_en': '2026-09-22T00:00:00+00:00',
      }),
      throwsArgumentError,
    );
  });
}
