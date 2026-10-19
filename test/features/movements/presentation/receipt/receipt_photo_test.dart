import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/widgets/widgets.dart';
import 'package:mislukas/features/movements/domain/repositories/receipt_image_store.dart';
import 'package:mislukas/features/movements/presentation/receipt/receipt_photo.dart';

import '../../../../helpers/fake_receipt_services.dart';
import '../../../../helpers/pump_screen.dart';
import '../../../../helpers/test_container.dart';

void main() {
  test(
    'sin ruta local (recibo de otro celular): no está en este celular',
    () async {
      final (container, _) = await createTestContainer(
        seed: false,
        overrides: receiptServiceOverrides(),
      );
      final image = await container.read(
        receiptImageProvider((localPath: null, receiptId: 'r1')).future,
      );
      expect(image, isA<ReceiptImageNotOnDevice>());
    },
  );

  test('si el almacén falla, nunca lanza: no se puede mostrar', () async {
    final (container, _) = await createTestContainer(
      seed: false,
      overrides: receiptServiceOverrides(store: _ThrowingStore()),
    );
    final image = await container.read(
      receiptImageProvider((localPath: 'recibos/r1.enc', receiptId: 'r1'))
          .future,
    );
    expect(image, isA<ReceiptImageUnreadable>());
  });

  testWidgets('ReceiptPhoto muestra el mensaje de cada caso sin fallar', (
    tester,
  ) async {
    final store = FakeReceiptImageStore()
      ..images['recibos/r2.enc'] = const ReceiptImageUnreadable();
    await pumpScreen(
      tester,
      ListView(
        children: const [
          ReceiptPhoto(localPath: null, receiptId: 'r1'),
          ReceiptPhoto(localPath: 'recibos/r2.enc', receiptId: 'r2'),
        ],
      ),
      overrides: receiptServiceOverrides(store: store),
    );

    expect(find.text(ReceiptPreview.notOnDeviceMessage), findsOneWidget);
    expect(find.text(ReceiptPreview.unreadableMessage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _ThrowingStore extends FakeReceiptImageStore {
  @override
  Future<ReceiptImage> read(
    String? relativePath, {
    required String receiptId,
  }) async => throw StateError('almacenamiento');
}
