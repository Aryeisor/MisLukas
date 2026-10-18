import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../domain/repositories/receipt_capture_services.dart';
import 'receipt_capture_settings.dart';

/// Permiso de cámara con permission_handler (docs/07 §7.9).
class PermissionHandlerCameraPermission implements CameraPermissionService {
  const PermissionHandlerCameraPermission();

  @override
  Future<CameraPermissionStatus> status() async =>
      _map(await Permission.camera.status);

  @override
  Future<CameraPermissionStatus> request() async =>
      _map(await Permission.camera.request());

  @override
  Future<bool> openSettings() => openAppSettings();

  static CameraPermissionStatus _map(PermissionStatus status) =>
      switch (status) {
        PermissionStatus.granted ||
        PermissionStatus.limited => CameraPermissionStatus.granted,
        PermissionStatus.permanentlyDenied =>
          CameraPermissionStatus.permanentlyDenied,
        PermissionStatus.restricted => CameraPermissionStatus.restricted,
        PermissionStatus.denied ||
        PermissionStatus.provisional => CameraPermissionStatus.denied,
      };
}

/// Selector de fotos del sistema con image_picker (docs/07 §7.2): la app solo
/// recibe la imagen elegida y no necesita permiso de la galería.
class ImagePickerReceiptPicker implements ReceiptImagePicker {
  ImagePickerReceiptPicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<String?> pickFromGallery() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: receiptGalleryMaxSide,
      maxHeight: receiptGalleryMaxSide,
      imageQuality: receiptGalleryQuality,
      // Sin metadatos: en iOS no pide el permiso de la biblioteca.
      requestFullMetadata: false,
    );
    if (file == null) return null;
    await _deleteOriginalCopy(file.path);
    return file.path;
  }

  /// En Android, image_picker copia la foto a `cache/<uuid>/<nombre>` y, si
  /// la reduce, deja la versión reducida en `cache/scaled_<nombre>`. La copia
  /// original no se usa: se borra para no dejar el recibo sin cifrar.
  static Future<void> _deleteOriginalCopy(String pickedPath) async {
    const prefix = 'scaled_';
    final name = p.basename(pickedPath);
    if (!Platform.isAndroid || !name.startsWith(prefix)) return;
    final original = name.substring(prefix.length);
    try {
      final cache = await getTemporaryDirectory();
      await for (final entity in cache.list()) {
        if (entity is! Directory) continue;
        final copy = File(p.join(entity.path, original));
        if (await copy.exists()) {
          await copy.delete();
          if (await entity.list().isEmpty) await entity.delete();
        }
      }
    } catch (_) {
      // La limpieza del arranque también revisa la caché.
    }
  }
}
