import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Por qué no se puede mostrar la foto de un recibo.
enum ReceiptPreviewUnavailable {
  /// El recibo no tiene foto en este celular (llegó desde otro).
  notOnDevice,

  /// La foto existe, pero no se pudo descifrar o no es una imagen válida.
  unreadable,
}

/// Vista previa de la foto del recibo sobre fondo oscuro, con el área del
/// total resaltada como "Área detectada" (docs/05, pantalla 7).
///
/// La imagen llega descifrada en memoria ([imageBytes]); nunca se lee de un
/// archivo. Si no hay imagen, muestra un mensaje en el mismo marco y la
/// pantalla sigue funcionando.
class ReceiptPreview extends StatelessWidget {
  /// La foto, con el total resaltado en [detectedArea] (en píxeles de la
  /// imagen, ya orientada).
  const ReceiptPreview.image(
    Uint8List this.imageBytes, {
    super.key,
    this.detectedArea,
  }) : unavailable = null;

  /// Mientras se descifra la foto.
  const ReceiptPreview.loading({super.key})
    : imageBytes = null,
      detectedArea = null,
      unavailable = null;

  /// Sin foto, con el mensaje de [reason].
  const ReceiptPreview.unavailable(
    ReceiptPreviewUnavailable reason, {
    super.key,
  }) : imageBytes = null,
       detectedArea = null,
       unavailable = reason;

  final Uint8List? imageBytes;
  final Rect? detectedArea;
  final ReceiptPreviewUnavailable? unavailable;

  static const String notOnDeviceMessage =
      'La foto solo está en el celular donde se tomó.';
  static const String unreadableMessage =
      'No pudimos mostrar la foto del recibo.';

  @override
  Widget build(BuildContext context) {
    final bytes = imageBytes;
    final Widget content;
    if (bytes != null) {
      content = _HighlightedImage(bytes: bytes, detectedArea: detectedArea);
    } else if (unavailable != null) {
      content = _UnavailableMessage(reason: unavailable!);
    } else {
      content = Semantics(
        label: 'Cargando la foto del recibo',
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.surface),
        ),
      );
    }

    return Container(
      height: AppSizes.receiptPreviewHeight,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.action,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: content,
    );
  }
}

class _UnavailableMessage extends StatelessWidget {
  const _UnavailableMessage({required this.reason});

  final ReceiptPreviewUnavailable reason;

  @override
  Widget build(BuildContext context) {
    final (icon, message) = switch (reason) {
      ReceiptPreviewUnavailable.notOnDevice => (
        Icons.phone_android_outlined,
        ReceiptPreview.notOnDeviceMessage,
      ),
      ReceiptPreviewUnavailable.unreadable => (
        Icons.hide_image_outlined,
        ReceiptPreview.unreadableMessage,
      ),
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSizes.iconXl, color: AppColors.surface),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.surface),
          ),
        ],
      ),
    );
  }
}

/// La foto ajustada al marco y, encima, el recuadro del total.
class _HighlightedImage extends StatefulWidget {
  const _HighlightedImage({required this.bytes, this.detectedArea});

  final Uint8List bytes;
  final Rect? detectedArea;

  @override
  State<_HighlightedImage> createState() => _HighlightedImageState();
}

class _HighlightedImageState extends State<_HighlightedImage> {
  /// Tamaño del archivo según su encabezado (sin la orientación EXIF).
  Size? _headerSize;

  /// Tamaño de la imagen decodificada: ya orientada y reducida al ancho de la
  /// pantalla.
  Size? _shownSize;

  ImageProvider? _provider;
  int? _cacheWidth;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    if (widget.detectedArea != null) _readHeader();
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }

  /// Lee el tamaño del archivo sin decodificarlo.
  Future<void> _readHeader() async {
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(widget.bytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final size = Size(
        descriptor.width.toDouble(),
        descriptor.height.toDouble(),
      );
      descriptor.dispose();
      buffer.dispose();
      if (mounted) setState(() => _headerSize = size);
    } catch (_) {
      // Sin tamaño, la foto se muestra sin resaltar.
    }
  }

  /// La imagen se decodifica al ancho de la pantalla, no al de la foto, para
  /// no ocupar memoria de más en un celular de gama baja.
  ImageProvider _providerFor(int cacheWidth) {
    final current = _provider;
    if (current != null && cacheWidth == _cacheWidth) return current;
    _stopListening();
    _cacheWidth = cacheWidth;
    final provider = ResizeImage(MemoryImage(widget.bytes), width: cacheWidth);
    _provider = provider;
    if (widget.detectedArea != null) {
      final stream = provider.resolve(ImageConfiguration.empty);
      final listener = ImageStreamListener((info, _) {
        final size = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );
        info.dispose();
        if (mounted && size != _shownSize) setState(() => _shownSize = size);
      }, onError: (_, _) {});
      stream.addListener(listener);
      _stream = stream;
      _listener = listener;
    }
    return provider;
  }

  void _stopListening() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = constraints.biggest;
        final pixelRatio = MediaQuery.devicePixelRatioOf(context);
        final provider = _providerFor(
          (box.width * pixelRatio).round().clamp(1, 4096),
        );
        final image = Image(
          image: provider,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          // Sin log: la imagen es un dato del usuario.
          errorBuilder: (context, error, stackTrace) =>
              const _UnavailableMessage(
                reason: ReceiptPreviewUnavailable.unreadable,
              ),
          // Decodificar desde memoria toma milisegundos: sin indicador.
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
              frame == null ? const SizedBox.shrink() : child,
        );
        final highlight = _highlightRect(box);
        return Semantics(
          image: true,
          label: highlight != null
              ? 'Foto del recibo con el total resaltado'
              : 'Foto del recibo',
          child: highlight == null
              ? Center(child: image)
              : _withHighlight(image, box, highlight),
        );
      },
    );
  }

  /// Recuadro del total en el marco de [box], o null si no se puede ubicar.
  Rect? _highlightRect(Size box) {
    final area = widget.detectedArea;
    final header = _headerSize;
    final shown = _shownSize;
    if (area == null || header == null || shown == null) return null;

    // Si la imagen mostrada está girada respecto al encabezado (EXIF), se
    // intercambian ancho y alto.
    final rotated =
        (shown.width > shown.height) != (header.width > header.height);
    final upright = rotated ? Size(header.height, header.width) : header;
    final normalized = Rect.fromLTRB(
      area.left / upright.width,
      area.top / upright.height,
      area.right / upright.width,
      area.bottom / upright.height,
    );
    const tolerance = 0.02;
    if (normalized.isEmpty ||
        normalized.left < -tolerance ||
        normalized.top < -tolerance ||
        normalized.right > 1 + tolerance ||
        normalized.bottom > 1 + tolerance) {
      return null;
    }

    final fitted = applyBoxFit(BoxFit.contain, shown, box).destination;
    final dx = (box.width - fitted.width) / 2;
    final dy = (box.height - fitted.height) / 2;
    return Rect.fromLTRB(
      dx + normalized.left.clamp(0.0, 1.0) * fitted.width,
      dy + normalized.top.clamp(0.0, 1.0) * fitted.height,
      dx + normalized.right.clamp(0.0, 1.0) * fitted.width,
      dy + normalized.bottom.clamp(0.0, 1.0) * fitted.height,
    ).inflate(AppSpacing.xs);
  }

  Widget _withHighlight(Widget image, Size box, Rect highlight) {
    final labelBelow = highlight.bottom + AppSpacing.xl < box.height;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: Center(child: image)),
        Positioned.fromRect(
          rect: highlight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: AppColors.primary,
                width: AppSizes.borderWidthSelected,
              ),
            ),
          ),
        ),
        Positioned(
          right: (box.width - highlight.right).clamp(0.0, box.width),
          top: labelBelow ? highlight.bottom + AppSpacing.xs : null,
          bottom: labelBelow
              ? null
              : box.height - highlight.top + AppSpacing.xs,
          child: const _DetectedLabel(),
        ),
      ],
    );
  }
}

/// Etiqueta "Área detectada" junto al recuadro del total.
class _DetectedLabel extends StatelessWidget {
  const _DetectedLabel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs / 2,
      ),
      decoration: const ShapeDecoration(
        color: AppColors.primary,
        shape: StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.circle,
            size: AppSizes.iconXs / 2,
            color: AppColors.surface,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Área detectada',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: AppColors.surface, letterSpacing: 0),
          ),
        ],
      ),
    );
  }
}
