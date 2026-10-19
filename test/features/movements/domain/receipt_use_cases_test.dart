import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';
import 'package:mislukas/features/movements/domain/entities/movement.dart';
import 'package:mislukas/features/movements/domain/entities/receipt.dart';
import 'package:mislukas/features/movements/domain/entities/receipt_suggestion.dart';
import 'package:mislukas/features/movements/domain/usecases/clean_receipt_images.dart';
import 'package:mislukas/features/movements/domain/usecases/delete_movement.dart';
import 'package:mislukas/features/movements/domain/usecases/scan_receipt.dart';

import '../../../helpers/domain_fixtures.dart';
import '../../../helpers/fake_receipt_services.dart';
import '../../../helpers/fake_repositories.dart';

void main() {
  group('ScanReceipt', () {
    test('lee la imagen y devuelve la sugerencia', () async {
      final reader = FakeReceiptTextReader(
        text: 'TIENDAS D1\nFECHA 20/09/2026\nTOTAL \$ 6.940',
      );
      final result = await ScanReceipt(
        reader: reader,
        clock: testClock,
      ).call('tmp/r1.jpg');

      expect(reader.readPaths, ['tmp/r1.jpg']);
      expect(result.status, ReceiptScanStatus.complete);
      expect(result.total, 6940);
      expect(result.merchant, 'D1');
      expect(result.category, DefaultCategory.mercado);
      expect(result.date, DateTime(2026, 9, 20));
    });

    test('si el OCR falla, sugerencia vacía con fecha de hoy', () async {
      final result = await ScanReceipt(
        reader: FakeReceiptTextReader(fails: true),
        clock: testClock,
      ).call('tmp/r1.jpg');

      expect(result.status, ReceiptScanStatus.empty);
      expect(result.total, isNull);
      expect(result.merchant, isNull);
      expect(result.date, DateTime(2026, 9, 22));
    });

    test('una fecha futura en el recibo se reemplaza por hoy', () async {
      final result = await ScanReceipt(
        reader: FakeReceiptTextReader(
          text: 'COMERCIO\n30/09/2026\nTOTAL 1.000',
        ),
        clock: testClock,
      ).call('tmp/r1.jpg');
      expect(result.date, DateTime(2026, 9, 22));
    });
  });

  group('CleanReceiptImages', () {
    test(
      'conserva las de recibos activos y las de los recibos en curso',
      () async {
        final movements = FakeMovementRepository();
        final active = testMovement(id: 'activo', origin: MovementOrigin.photo);
        await movements.add(
          active,
          receipt: const Receipt(
            id: 'r-activo',
            movementId: 'activo',
            localPath: 'recibos/r-activo.enc',
          ),
        );
        final store = FakeReceiptImageStore()
          ..stored.addAll({
            'recibos/r-activo.enc',
            'recibos/huerfano.enc',
            'recibos/en-curso.enc',
          });

        await CleanReceiptImages(
          movements: movements,
          images: store,
        ).call(inProgress: {'en-curso'});

        expect(store.lastCleanUp!.keepPaths, {'recibos/r-activo.enc'});
        expect(store.lastCleanUp!.keepReceiptIds, {'en-curso'});
        expect(store.stored, {'recibos/r-activo.enc', 'recibos/en-curso.enc'});
      },
    );
  });

  group('DeleteMovement', () {
    test('borra la imagen del recibo del movimiento', () async {
      final movements = FakeMovementRepository();
      await movements.add(
        testMovement(id: 'm1', origin: MovementOrigin.photo),
        receipt: const Receipt(
          id: 'r1',
          movementId: 'm1',
          localPath: 'recibos/r1.enc',
        ),
      );
      final store = FakeReceiptImageStore()..stored.add('recibos/r1.enc');

      await DeleteMovement(
        movements: movements,
        clock: testClock,
        images: store,
      ).call('m1');

      expect((await movements.findById('m1')), isNull);
      expect(store.deleted, ['recibos/r1.enc']);
      expect(store.stored, isEmpty);
    });

    test('un movimiento sin recibo no toca imágenes', () async {
      final movements = FakeMovementRepository([testMovement(id: 'm1')]);
      final store = FakeReceiptImageStore();

      await DeleteMovement(
        movements: movements,
        clock: testClock,
        images: store,
      ).call('m1');

      expect(store.deleted, isEmpty);
    });
  });
}
