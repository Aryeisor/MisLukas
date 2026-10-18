import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../../core/database/database_connection.dart';
import '../../domain/repositories/receipt_cipher.dart';
import '../../domain/repositories/receipt_image_store.dart';

/// Imágenes de recibos en `<soporte de la app>/recibos/` (docs/07 §7.5).
///
/// - `recibos/tmp/<id>.<ext>`: la imagen sin cifrar, solo mientras corre el
///   OCR. Fuera de la caché, para que otra herramienta del sistema no la
///   copie.
/// - `recibos/<id>.enc`: la imagen cifrada con AES-GCM, ligada al id del
///   recibo. Se escribe en `.<id>.tmp` y se renombra, para no dejar archivos a
///   medias.
///
/// La ruta que se guarda en la base es relativa (`recibos/<id>.enc`): la ruta
/// absoluta del contenedor de la app puede cambiar (iOS, al actualizar).
/// Nunca escribe rutas ni contenidos en logs.
class FileReceiptImageStore implements ReceiptImageStore {
  FileReceiptImageStore({
    required this._directory,
    required this._cipher,
    this._cacheDirectory,
    this.maxBytes = defaultMaxBytes,
  });

  /// Directorio de soporte de la app, donde también está la base.
  final Future<Directory> Function() _directory;

  /// Caché de la app, donde la cámara y el selector de fotos dejan la imagen
  /// antes de que se mueva a `recibos/tmp/`.
  final Future<Directory> Function()? _cacheDirectory;
  final ReceiptCipher _cipher;

  /// Tamaño máximo de una imagen.
  final int maxBytes;

  /// 5 MB, el mismo límite del bucket privado de Storage.
  static const int defaultMaxBytes = 5 * 1024 * 1024;

  static const String _tmpDirectoryName = 'tmp';
  static const String _encryptedExtension = '.enc';
  static const Set<String> _imageExtensions = {'.jpg', '.jpeg', '.png'};

  /// Un id de recibo: UUID u otro texto sin separadores de ruta.
  static final RegExp _safeId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  /// Ruta relativa válida de una imagen cifrada.
  static final RegExp _relativePath = RegExp(
    '^$receiptsDirectoryName/[A-Za-z0-9_-]{1,64}\\$_encryptedExtension\$',
  );

  /// Ruta relativa de la imagen cifrada del recibo [receiptId].
  static String relativePathFor(String receiptId) =>
      '$receiptsDirectoryName/$receiptId$_encryptedExtension';

  Future<Directory> _receipts() async =>
      Directory(p.join((await _directory()).path, receiptsDirectoryName));

  Future<Directory> _tmp() async =>
      Directory(p.join((await _receipts()).path, _tmpDirectoryName));

  @override
  Future<String> stage(String sourcePath, {required String receiptId}) async {
    _checkId(receiptId);
    final source = File(sourcePath);
    try {
      if (await source.length() > maxBytes) {
        throw const ReceiptImageException(ReceiptImageError.tooLarge);
      }
      final tmp = await _tmp();
      await tmp.create(recursive: true);
      var extension = p.extension(sourcePath).toLowerCase();
      if (!_imageExtensions.contains(extension)) extension = '.jpg';
      final target = p.join(tmp.path, '$receiptId$extension');
      await _move(source, target);
      return target;
    } on ReceiptImageException {
      rethrow;
    } catch (_) {
      throw const ReceiptImageException(ReceiptImageError.failed);
    } finally {
      await _deleteQuietly(source);
    }
  }

  @override
  Future<void> discardStaged(String receiptId) async {
    if (!_safeId.hasMatch(receiptId)) return;
    try {
      final tmp = await _tmp();
      if (!await tmp.exists()) return;
      await for (final entity in tmp.list()) {
        if (entity is File && _idOf(entity.path) == receiptId) {
          await _deleteQuietly(entity);
        }
      }
    } catch (_) {
      // La limpieza del próximo arranque lo borra.
    }
  }

  @override
  Future<String> encryptAndStore(
    String stagedPath, {
    required String receiptId,
  }) async {
    _checkId(receiptId);
    final receipts = await _receipts();
    // Solo imágenes de la carpeta temporal: un archivo de otro lugar no se
    // cifra ni se borra.
    if (!p.isWithin(p.join(receipts.path, _tmpDirectoryName), stagedPath)) {
      throw const ReceiptImageException(ReceiptImageError.failed);
    }
    final staged = File(stagedPath);
    File? partial;
    try {
      final clear = await staged.readAsBytes();
      final sealed = await _cipher.encrypt(
        clear,
        associatedData: utf8.encode(receiptId),
      );
      partial = File(p.join(receipts.path, '.$receiptId.tmp'));
      await partial.writeAsBytes(sealed, flush: true);
      await partial.rename(
        p.join(receipts.path, '$receiptId$_encryptedExtension'),
      );
      partial = null;
      return relativePathFor(receiptId);
    } on ReceiptImageException {
      rethrow;
    } catch (_) {
      throw const ReceiptImageException(ReceiptImageError.failed);
    } finally {
      // La imagen sin cifrar no se conserva nunca, salga bien o no.
      await _deleteQuietly(staged);
      if (partial != null) await _deleteQuietly(partial);
    }
  }

  @override
  Future<ReceiptImage> read(
    String? relativePath, {
    required String receiptId,
  }) async {
    if (relativePath == null) return const ReceiptImageNotOnDevice();
    try {
      if (!_relativePath.hasMatch(relativePath)) {
        return const ReceiptImageUnreadable();
      }
      final file = File(p.join((await _directory()).path, relativePath));
      if (!await file.exists()) return const ReceiptImageNotOnDevice();
      final clear = await _cipher.decrypt(
        await file.readAsBytes(),
        associatedData: utf8.encode(receiptId),
      );
      return ReceiptImageAvailable(clear);
    } catch (_) {
      return const ReceiptImageUnreadable();
    }
  }

  @override
  Future<void> delete(String? relativePath) async {
    if (relativePath == null || !_relativePath.hasMatch(relativePath)) return;
    try {
      await _deleteQuietly(
        File(p.join((await _directory()).path, relativePath)),
      );
    } catch (_) {
      // La limpieza del próximo arranque lo borra.
    }
  }

  @override
  Future<void> cleanUp({
    required Set<String> keepPaths,
    required Set<String> keepReceiptIds,
  }) async {
    await _cleanCaptureCache();
    final receipts = await _receipts();
    if (!await receipts.exists()) return;

    await for (final entity in receipts.list()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      final relative = '$receiptsDirectoryName/$name';
      final id = _idOf(entity.path);
      if (keepReceiptIds.contains(id)) continue;
      if (name.endsWith(_encryptedExtension) && keepPaths.contains(relative)) {
        continue;
      }
      // Imágenes huérfanas y escrituras a medias.
      await _deleteQuietly(entity);
    }

    final tmp = await _tmp();
    if (!await tmp.exists()) return;
    await for (final entity in tmp.list()) {
      if (entity is File && !keepReceiptIds.contains(_idOf(entity.path))) {
        await _deleteQuietly(entity);
      }
    }
  }

  /// Fotos que quedaron en la caché si la app se cerró entre la captura y
  /// [stage]: las de la cámara (`CAP*.jpg`), las reducidas por image_picker
  /// (`scaled_*`) y sus copias (`<uuid>/<nombre>`).
  Future<void> _cleanCaptureCache() async {
    final cacheDirectory = _cacheDirectory;
    if (cacheDirectory == null) return;
    try {
      final cache = await cacheDirectory();
      if (!await cache.exists()) return;
      await for (final entity in cache.list()) {
        if (entity is File && _isCaptureLeftover(entity.path)) {
          await _deleteQuietly(entity);
        } else if (entity is Directory &&
            _uuidDirectory.hasMatch(p.basename(entity.path))) {
          await for (final child in entity.list()) {
            if (child is File && _isImage(child.path)) {
              await _deleteQuietly(child);
            }
          }
          if (await entity.list().isEmpty) await entity.delete();
        }
      }
    } catch (_) {
      // Se intenta de nuevo en el próximo arranque.
    }
  }

  static final RegExp _uuidDirectory = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static bool _isImage(String path) => {
    ..._imageExtensions,
    '.heic',
    '.webp',
  }.contains(p.extension(path).toLowerCase());

  static bool _isCaptureLeftover(String path) {
    final name = p.basename(path);
    return _isImage(path) &&
        (name.startsWith('CAP') || name.startsWith('scaled_'));
  }

  /// Id del recibo a partir del nombre del archivo: `<id>.enc`,
  /// `.<id>.tmp` o `<id>.jpg`.
  static String _idOf(String path) {
    var name = p.basename(path);
    if (name.startsWith('.')) name = name.substring(1);
    final dot = name.indexOf('.');
    return dot < 0 ? name : name.substring(0, dot);
  }

  static void _checkId(String receiptId) {
    if (!_safeId.hasMatch(receiptId)) {
      throw const ReceiptImageException(ReceiptImageError.failed);
    }
  }

  /// Mueve [source] a [target]. Si están en sistemas de archivos distintos,
  /// lo copia (el original se borra después).
  static Future<void> _move(File source, String target) async {
    try {
      await source.rename(target);
    } on FileSystemException {
      await source.copy(target);
    }
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Sin log: la ruta es un dato del dispositivo.
    }
  }
}
