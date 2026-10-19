import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/widgets.dart';
import '../../data/movements_providers.dart';
import '../../domain/entities/recognized_receipt.dart';
import '../../domain/repositories/receipt_image_store.dart';

/// Imagen de un recibo: su ruta local (null si no está en este celular) y el
/// id con el que se cifró.
typedef ReceiptImageKey = ({String? localPath, String receiptId});

/// La foto del recibo descifrada en memoria. Nunca falla: cualquier error es
/// [ReceiptImageUnreadable]. Se libera al cerrar la pantalla.
final receiptImageProvider = FutureProvider.autoDispose
    .family<ReceiptImage, ReceiptImageKey>((ref, key) async {
      try {
        return await ref
            .read(receiptImageStoreProvider)
            .read(key.localPath, receiptId: key.receiptId);
      } catch (_) {
        return const ReceiptImageUnreadable();
      }
    });

/// Foto del recibo [receiptId] con el total resaltado en [detectedArea]. Si
/// no está en este celular o no se puede descifrar, muestra un mensaje en su
/// lugar y la pantalla sigue funcionando.
class ReceiptPhoto extends ConsumerWidget {
  const ReceiptPhoto({
    super.key,
    required this.localPath,
    required this.receiptId,
    this.detectedArea,
  });

  final String? localPath;
  final String receiptId;
  final ReceiptBox? detectedArea;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref.watch(
      receiptImageProvider((localPath: localPath, receiptId: receiptId)),
    );
    final area = detectedArea;
    return switch (image) {
      AsyncData(value: ReceiptImageAvailable(:final bytes)) =>
        ReceiptPreview.image(
          bytes,
          detectedArea: area == null
              ? null
              : Rect.fromLTRB(area.left, area.top, area.right, area.bottom),
        ),
      AsyncData(value: ReceiptImageNotOnDevice()) =>
        const ReceiptPreview.unavailable(ReceiptPreviewUnavailable.notOnDevice),
      AsyncData(value: ReceiptImageUnreadable()) || AsyncError() =>
        const ReceiptPreview.unavailable(ReceiptPreviewUnavailable.unreadable),
      _ => const ReceiptPreview.loading(),
    };
  }
}
