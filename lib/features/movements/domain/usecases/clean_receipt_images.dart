import '../repositories/movement_repository.dart';
import '../repositories/receipt_image_store.dart';

/// Borra las imágenes de recibos que ya no tienen un recibo activo: las de un
/// registro que se interrumpió (la app se cerró a mitad del flujo) y las de
/// recibos eliminados, también desde otro celular (docs/07 §7.5).
///
/// Las de los recibos [inProgress] (captura o confirmación abiertas) no se
/// tocan: todavía no tienen fila en la base.
class CleanReceiptImages {
  const CleanReceiptImages({required this._movements, required this._images});

  final MovementRepository _movements;
  final ReceiptImageStore _images;

  Future<void> call({Set<String> inProgress = const {}}) async {
    final keep = await _movements.activeReceiptPaths();
    await _images.cleanUp(keepPaths: keep, keepReceiptIds: inProgress);
  }
}
