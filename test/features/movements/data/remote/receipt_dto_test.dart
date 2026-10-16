import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/database/app_database.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';
import 'package:mislukas/features/movements/data/remote/receipt_dto.dart';

import '../../../../helpers/test_database.dart';

Map<String, dynamic> overTheWire(Map<String, dynamic> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

void main() {
  late AppDatabase db;

  final at = DateTime.utc(2026, 9, 22, 14, 30, 5, 123, 456);

  setUp(() async {
    db = openTestDatabase();
    await db
        .into(db.movements)
        .insert(
          MovementsCompanion.insert(
            id: 'm1',
            categoryId: DefaultCategory.mercado.id,
            type: 'gasto',
            amount: 87400,
            date: DateTime(2026, 9, 22),
            description: 'Éxito',
            origin: 'foto',
            createdAt: at,
            updatedAt: at,
          ),
        );
  });
  tearDown(() => db.close());

  final local = ReceiptsCompanion.insert(
    id: 'r1',
    movementId: 'm1',
    localPath: const Value('recibos/r1.jpg'),
    detectedTotal: const Value(87400),
    detectedMerchant: const Value('Éxito'),
    createdAt: at,
    updatedAt: at,
  );

  test('ida y vuelta conserva la fila y la ruta local', () async {
    await db.into(db.receipts).insert(local);
    final original = await db.select(db.receipts).getSingle();

    final json = overTheWire(ReceiptDto.fromRow(original).toJson());
    await db
        .into(db.receipts)
        .insertOnConflictUpdate(ReceiptDto.fromJson(json).toCompanion());

    expect(
      await db.select(db.receipts).getSingle(),
      original.copyWith(syncStatus: 'sincronizado'),
    );
  });

  test('un cambio del servidor no pisa la imagen local', () async {
    await db.into(db.receipts).insert(local);

    final remote = ReceiptDto.fromJson({
      'id': 'r1',
      'usuario_id': 'u1',
      'movimiento_id': 'm1',
      'ruta_storage': 'u1/r1.jpg',
      'total_detectado': 87400,
      'comercio_detectado': 'Almacenes Éxito',
      'creado_en': '2026-09-22T14:30:05.123456+00:00',
      'actualizado_en': '2026-09-25T10:00:00+00:00',
      'eliminado_en': '2026-09-25T10:00:00+00:00',
      'sincronizado_en': '2026-09-25T10:00:01+00:00',
    });
    await db.into(db.receipts).insertOnConflictUpdate(remote.toCompanion());

    final saved = await db.select(db.receipts).getSingle();
    expect(saved.localPath, 'recibos/r1.jpg');
    expect(saved.detectedMerchant, 'Almacenes Éxito');
    expect(saved.deletedAt, DateTime.utc(2026, 9, 25, 10));
    expect(saved.syncStatus, 'sincronizado');
  });

  test('un recibo nuevo del servidor llega sin imagen local', () async {
    final remote = ReceiptDto.fromJson({
      'id': 'r2',
      'movimiento_id': 'm1',
      'ruta_storage': null,
      'total_detectado': null,
      'comercio_detectado': null,
      'creado_en': '2026-09-22T14:30:05+00:00',
      'actualizado_en': '2026-09-22T14:30:05+00:00',
      'eliminado_en': null,
    });
    await db.into(db.receipts).insert(remote.toCompanion());

    final saved = await db.select(db.receipts).getSingle();
    expect(saved.localPath, isNull);
    expect(saved.detectedTotal, isNull);
  });

  test(
    'el JSON enviado no lleva la ruta local ni campos del servidor',
    () async {
      await db.into(db.receipts).insert(local);
      final json = ReceiptDto.fromRow(await db.select(db.receipts).getSingle())
          .toJson();

      expect(json.keys, isNot(contains('ruta_local')));
      expect(json.keys, isNot(contains('usuario_id')));
      expect(json.keys, isNot(contains('sincronizado_en')));
      // Sin respaldo, no se envía ruta_storage para no borrar uno existente.
      expect(json.keys, isNot(contains('ruta_storage')));
      expect(json['total_detectado'], 87400);
    },
  );

  test('ruta_storage se envía cuando existe', () {
    final dto = ReceiptDto(
      id: 'r1',
      movementId: 'm1',
      storagePath: 'u1/r1.jpg',
      createdAt: at,
      updatedAt: at,
    );
    expect(dto.toJson()['ruta_storage'], 'u1/r1.jpg');
  });

  test('rechaza un total con decimales', () {
    expect(
      () => ReceiptDto.fromJson({
        'id': 'r1',
        'movimiento_id': 'm1',
        'total_detectado': 874.5,
        'creado_en': '2026-09-22T14:30:05+00:00',
        'actualizado_en': '2026-09-22T14:30:05+00:00',
      }),
      throwsFormatException,
    );
  });
}
