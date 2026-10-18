import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/widgets/widgets.dart';

import '../../helpers/fake_receipt_services.dart';
import '../../helpers/pump_themed.dart';

void main() {
  testWidgets('foto de otro celular: mensaje sin fallar', (tester) async {
    await pumpThemed(
      tester,
      const ReceiptPreview.unavailable(ReceiptPreviewUnavailable.notOnDevice),
    );
    expect(find.text(ReceiptPreview.notOnDeviceMessage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('foto que no se puede descifrar: mensaje sin fallar', (
    tester,
  ) async {
    await pumpThemed(
      tester,
      const ReceiptPreview.unavailable(ReceiptPreviewUnavailable.unreadable),
    );
    expect(find.text(ReceiptPreview.unreadableMessage), findsOneWidget);
  });

  testWidgets('bytes que no son una imagen: mensaje de no se puede mostrar', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await pumpThemed(
        tester,
        ReceiptPreview.image(Uint8List.fromList([1, 2, 3, 4, 5])),
      );
      // Deja que el decodificador del motor responda.
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    expect(find.text(ReceiptPreview.unreadableMessage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('una imagen válida se muestra con su descripción', (
    tester,
  ) async {
    await pumpThemed(
      tester,
      ReceiptPreview.image(
        tinyPng,
        detectedArea: const Rect.fromLTWH(0, 0, 1, 1),
      ),
    );
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
