import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/database/app_database.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';
import 'package:mislukas/features/movements/data/remote/movement_dto.dart';
import 'package:mislukas/features/movements/domain/entities/movement.dart';

import '../../../../helpers/test_database.dart';

/// Simula el viaje por la red: el JSON se codifica y decodifica como texto.
Map<String, dynamic> overTheWire(Map<String, dynamic> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  final createdAt = DateTime.utc(2026, 9, 22, 14, 30, 5, 123, 456);
  final updatedAt = DateTime.utc(2026, 9, 23, 8, 0, 0, 1);

  final expense = MovementsCompanion.insert(
    id: '0b6c3f43-6a52-4a8b-9a59-3a6f2f8f5e01',
    categoryId: DefaultCategory.mercado.id,
    type: 'gasto',
    amount: 87400,
    date: DateTime(2026, 9, 22),
    description: 'Éxito',
    note: const Value("Con 'comillas' y ; DROP TABLE movimientos; --"),
    origin: 'foto',
    createdAt: createdAt,
    updatedAt: updatedAt,
    deletedAt: Value(DateTime.utc(2026, 9, 24, 9)),
  );

  final income = MovementsCompanion.insert(
    id: '0b6c3f43-6a52-4a8b-9a59-3a6f2f8f5e02',
    categoryId: DefaultCategory.ingreso.id,
    type: 'ingreso',
    amount: 3500000,
    date: DateTime(2026, 9, 1),
    description: 'Salario',
    origin: 'manual',
    createdAt: createdAt,
    updatedAt: createdAt,
  );

  for (final (name, local) in [
    ('gasto eliminado', expense),
    ('ingreso', income),
  ]) {
    test(
      'ida y vuelta local → remoto → local conserva la fila ($name)',
      () async {
        await db.into(db.movements).insert(local);
        final original = await db.select(db.movements).getSingle();

        final json = overTheWire(MovementDto.fromRow(original).toJson());
        final back = MovementDto.fromJson(json).toCompanion();
        await db.delete(db.movements).go();
        await db.into(db.movements).insert(back);

        expect(
          await db.select(db.movements).getSingle(),
          original.copyWith(syncStatus: 'sincronizado'),
        );
      },
    );
  }

  test('lee el formato de PostgREST', () {
    final dto = MovementDto.fromJson({
      'id': 'm1',
      'usuario_id': 'u1',
      'categoria_id': DefaultCategory.ingreso.id,
      'tipo': 'ingreso',
      'monto': 3500000,
      'fecha': '2026-10-16',
      'descripcion': 'Salario',
      'nota': null,
      'origen': 'manual',
      'cuenta': 'principal',
      'creado_en': '2026-10-16T15:04:05.123456+00:00',
      'actualizado_en': '2026-10-16T10:04:05.123456-05:00',
      'eliminado_en': null,
      'sincronizado_en': '2026-10-16T15:04:06.5+00:00',
    });

    expect(dto.userId, 'u1');
    expect(dto.type, MovementType.income);
    expect(dto.origin, MovementOrigin.manual);
    expect(dto.amount, 3500000);
    expect(dto.date, DateTime(2026, 10, 16));
    expect(dto.createdAt, DateTime.utc(2026, 10, 16, 15, 4, 5, 123, 456));
    expect(dto.updatedAt, dto.createdAt);
    expect(dto.updatedAt.isUtc, isTrue);
    expect(dto.deletedAt, isNull);
    expect(dto.syncedAt, DateTime.utc(2026, 10, 16, 15, 4, 6, 500));
  });

  test('el JSON enviado no lleva usuario_id ni sincronizado_en', () async {
    await db.into(db.movements).insert(expense);
    final json = MovementDto.fromRow(await db.select(db.movements).getSingle())
        .toJson();

    expect(json.containsKey('usuario_id'), isFalse);
    expect(json.containsKey('sincronizado_en'), isFalse);
    expect(json.containsKey('estado_sync'), isFalse);
    expect(json['monto'], isA<int>());
    expect(json['fecha'], '2026-09-22');
    expect(json['tipo'], 'gasto');
    expect(json['origen'], 'foto');
    expect(json['creado_en'], '2026-09-22T14:30:05.123456Z');
    expect(json['eliminado_en'], '2026-09-24T09:00:00.000Z');
  });

  group('rechaza valores inválidos', () {
    Map<String, dynamic> valid() => {
      'id': 'm1',
      'categoria_id': DefaultCategory.mercado.id,
      'tipo': 'gasto',
      'monto': 1000,
      'fecha': '2026-10-16',
      'descripcion': 'x',
      'origen': 'manual',
      'cuenta': 'principal',
      'creado_en': '2026-10-16T15:04:05+00:00',
      'actualizado_en': '2026-10-16T15:04:05+00:00',
    };

    test('el JSON de referencia es válido', () {
      expect(() => MovementDto.fromJson(valid()), returnsNormally);
    });

    test('tipo u origen desconocidos', () {
      expect(
        () => MovementDto.fromJson({...valid(), 'tipo': 'saldo_inicial'}),
        throwsArgumentError,
      );
      expect(
        () => MovementDto.fromJson({...valid(), 'origen': 'correo'}),
        throwsArgumentError,
      );
    });

    test('monto con decimales o como texto', () {
      for (final amount in [1000.5, '1000', null]) {
        expect(
          () => MovementDto.fromJson({...valid(), 'monto': amount}),
          throwsFormatException,
        );
      }
    });

    test('fecha con hora, marca de tiempo inválida o id ausente', () {
      expect(
        () => MovementDto.fromJson({...valid(), 'fecha': '2026-10-16T00:00'}),
        throwsFormatException,
      );
      expect(
        () => MovementDto.fromJson({...valid(), 'creado_en': 'ayer'}),
        throwsFormatException,
      );
      expect(
        () => MovementDto.fromJson(valid()..remove('id')),
        throwsFormatException,
      );
    });

    test('el error nombra la columna, no el valor', () {
      expect(
        () => MovementDto.fromJson({...valid(), 'monto': '87400'}),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('monto'), isNot(contains('87400'))),
          ),
        ),
      );
    });
  });
}
