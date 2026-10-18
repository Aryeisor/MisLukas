import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/receipts/receipt_capture_settings.dart';
import '../../domain/repositories/receipt_image_store.dart';
import 'receipt_capture_view_model.dart';

/// Foto del recibo: visor de cámara propio con marco, linterna y galería, y
/// revisión de la foto antes de leerla (docs/07 §7.1). Pide el permiso en
/// el momento, con una explicación previa (§7.9).
class ReceiptCaptureScreen extends ConsumerStatefulWidget {
  const ReceiptCaptureScreen({super.key});

  @override
  ConsumerState<ReceiptCaptureScreen> createState() =>
      _ReceiptCaptureScreenState();
}

class _ReceiptCaptureScreenState extends ConsumerState<ReceiptCaptureScreen> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      // Al volver de Ajustes, el permiso pudo cambiar.
      onResume: () =>
          ref.read(receiptCaptureViewModelProvider.notifier).onResume(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  void _registerManually() =>
      context.pushReplacement(AppRoutes.confirmMovement);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(receiptCaptureViewModelProvider);
    final viewModel = ref.read(receiptCaptureViewModelProvider.notifier);
    ref.listen(receiptCaptureViewModelProvider, (_, next) {
      if (next is CaptureDone) {
        // Volver desde Confirma los datos lleva a Nuevo movimiento.
        context.pushReplacement(AppRoutes.confirmMovement, extra: next.capture);
      }
    });

    return switch (state) {
      CaptureCamera() => _ReceiptCameraView(
        onClose: _close,
        onPhotoTaken: viewModel.onPhotoTaken,
        onError: viewModel.onCameraError,
        onPickFromGallery: viewModel.pickFromGallery,
      ),
      CaptureReview(:final imagePath) => _ReviewView(
        imagePath: imagePath,
        onUse: viewModel.usePhoto,
        onRetake: viewModel.retake,
      ),
      _ => Scaffold(
        body: SafeArea(
          child: _MessageLayout(
            onClose: _close,
            child: switch (state) {
              CaptureExplainPermission() => _MessageContent(
                icon: Icons.photo_camera_outlined,
                title: 'Permite el acceso a la cámara',
                description:
                    'MisLukas usa la cámara para tomar la foto de tus recibos '
                    'y leer el valor automáticamente. Las fotos no se '
                    'comparten ni se guardan en tu galería.',
                primaryLabel: 'Permitir cámara',
                onPrimary: viewModel.requestPermission,
                secondary: [
                  ('Elegir de la galería', viewModel.pickFromGallery),
                  ('Ahora no', _close),
                ],
              ),
              CapturePermissionDenied(restricted: true) => _MessageContent(
                icon: Icons.no_photography_outlined,
                title: 'La cámara no está disponible',
                description:
                    'El sistema no permite usar la cámara en este celular. '
                    'Puedes elegir una foto de la galería o registrar el '
                    'gasto a mano.',
                primaryLabel: 'Elegir de la galería',
                onPrimary: viewModel.pickFromGallery,
                secondary: [('Registrar manual', _registerManually)],
              ),
              CapturePermissionDenied(permanently: true) => _MessageContent(
                icon: Icons.no_photography_outlined,
                title: 'La cámara está desactivada para MisLukas',
                description:
                    'Para tomar fotos de tus recibos, actívala en Ajustes › '
                    'Aplicaciones › MisLukas › Permisos › Cámara. También '
                    'puedes elegir una foto de la galería o registrar el '
                    'gasto a mano.',
                primaryLabel: 'Abrir Ajustes',
                onPrimary: viewModel.openSettings,
                secondary: [
                  ('Elegir de la galería', viewModel.pickFromGallery),
                  ('Registrar manual', _registerManually),
                ],
              ),
              CapturePermissionDenied() => _MessageContent(
                icon: Icons.no_photography_outlined,
                title: 'No tenemos acceso a la cámara',
                description:
                    'Puedes elegir una foto de la galería o registrar el '
                    'gasto a mano.',
                primaryLabel: 'Elegir de la galería',
                onPrimary: viewModel.pickFromGallery,
                secondary: [
                  ('Permitir cámara', viewModel.requestPermission),
                  ('Registrar manual', _registerManually),
                ],
              ),
              CaptureFailed(error: ReceiptImageError.tooLarge) =>
                _MessageContent(
                  icon: Icons.photo_size_select_large_outlined,
                  title: 'La imagen es muy grande',
                  description:
                      'Elige otra foto o tómala con la cámara de la app.',
                  primaryLabel: 'Intentar de nuevo',
                  onPrimary: viewModel.retry,
                  secondary: [('Registrar manual', _registerManually)],
                ),
              CaptureFailed() => _MessageContent(
                icon: Icons.error_outline,
                title: 'No pudimos procesar la foto',
                description: 'Intenta de nuevo o registra el gasto a mano.',
                primaryLabel: 'Intentar de nuevo',
                onPrimary: viewModel.retry,
                secondary: [('Registrar manual', _registerManually)],
              ),
              CaptureProcessing() ||
              CaptureDone() => const _Progress(label: 'Leyendo tu recibo…'),
              _ => const _Progress(label: 'Preparando la cámara…'),
            },
          ),
        ),
      ),
    };
  }
}

/// Encabezado con el botón de cerrar y el contenido debajo.
class _MessageLayout extends StatelessWidget {
  const _MessageLayout({required this.onClose, required this.child});

  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Foto del recibo',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ),
              AppIconButton(
                icon: Icons.close,
                tooltip: 'Cerrar',
                onPressed: onClose,
              ),
            ],
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _MessageContent extends StatelessWidget {
  const _MessageContent({
    required this.icon,
    required this.title,
    required this.description,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondary = const [],
  });

  final IconData icon;
  final String title;
  final String description;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final List<(String, VoidCallback)> secondary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: AppEmptyState(
              icon: icon,
              title: title,
              description: description,
            ),
          ),
        ),
        AppPrimaryButton(label: primaryLabel, onPressed: onPrimary),
        for (final (label, onPressed) in secondary) ...[
          const SizedBox(height: AppSpacing.sm),
          AppSecondaryButton(label: label, onPressed: onPressed),
        ],
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.lg),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// La foto recién tomada, para descartarla si salió borrosa.
class _ReviewView extends StatelessWidget {
  const _ReviewView({
    required this.imagePath,
    required this.onUse,
    required this.onRetake,
  });

  final String imagePath;
  final VoidCallback onUse;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.action,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Semantics(
                  image: true,
                  label: 'Foto del recibo tomada',
                  child: Image.file(
                    File(imagePath),
                    fit: BoxFit.contain,
                    // Se decodifica al tamaño de la pantalla.
                    cacheWidth:
                        (MediaQuery.sizeOf(context).width *
                                MediaQuery.devicePixelRatioOf(context))
                            .round(),
                  ),
                ),
              ),
            ),
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Column(
                children: [
                  Text(
                    '¿Se lee bien el total?',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppPrimaryButton(
                    label: 'Usar foto',
                    icon: Icons.check,
                    onPressed: onUse,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppSecondaryButton(
                    label: 'Repetir',
                    icon: Icons.refresh,
                    onPressed: onRetake,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Visor de la cámara con el marco de encuadre. El controlador se libera al
/// pasar a segundo plano y se crea de nuevo al volver, como pide el paquete
/// camera.
class _ReceiptCameraView extends StatefulWidget {
  const _ReceiptCameraView({
    required this.onClose,
    required this.onPhotoTaken,
    required this.onError,
    required this.onPickFromGallery,
  });

  final VoidCallback onClose;
  final ValueChanged<String> onPhotoTaken;
  final VoidCallback onError;
  final VoidCallback onPickFromGallery;

  @override
  State<_ReceiptCameraView> createState() => _ReceiptCameraViewState();
}

class _ReceiptCameraViewState extends State<_ReceiptCameraView>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _torchOn = false;
  bool _taking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      final controller = _controller;
      _controller = null;
      _torchOn = false;
      controller?.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && _controller == null) {
      _start();
    }
  }

  Future<void> _start() async {
    CameraController? controller;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw CameraException('sin-camara', null);
      final back = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      controller = CameraController(
        back,
        receiptCaptureResolution,
        // Sin micrófono (docs/07 §7.9.1).
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (_) {
      // Sin log: el detalle del error no le sirve al usuario.
      await controller?.dispose();
      if (mounted) widget.onError();
    }
  }

  Future<void> _toggleTorch() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.setFlashMode(_torchOn ? FlashMode.off : FlashMode.torch);
      if (mounted) setState(() => _torchOn = !_torchOn);
    } catch (_) {
      // Sin linterna en este celular: se sigue sin ella.
    }
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (controller == null || _taking || controller.value.isTakingPicture) {
      return;
    }
    setState(() => _taking = true);
    try {
      final file = await controller.takePicture();
      if (_torchOn) await controller.setFlashMode(FlashMode.off);
      widget.onPhotoTaken(file.path);
    } catch (_) {
      widget.onError();
    } finally {
      if (mounted) setState(() => _taking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.action,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Foto del recibo',
                        style: textTheme.titleMedium?.copyWith(
                          color: AppColors.surface,
                        ),
                      ),
                    ),
                  ),
                  AppIconButton(
                    icon: Icons.close,
                    tooltip: 'Cerrar',
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ready
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Center(child: CameraPreview(controller)),
                        const CustomPaint(painter: _FramePainter()),
                        Positioned(
                          left: AppSpacing.lg,
                          right: AppSpacing.lg,
                          bottom: AppSpacing.lg,
                          child: const ReceiptFrameHint(),
                        ),
                      ],
                    )
                  : const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.surface,
                      ),
                    ),
            ),
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Row(
                children: [
                  AppIconButton(
                    icon: Icons.photo_library_outlined,
                    tooltip: 'Elegir de la galería',
                    onPressed: widget.onPickFromGallery,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppIconButton(
                    icon: _torchOn ? Icons.flash_on : Icons.flash_off,
                    tooltip: _torchOn ? 'Apagar linterna' : 'Encender linterna',
                    onPressed: ready ? _toggleTorch : null,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppPrimaryButton(
                      label: 'Tomar foto',
                      icon: Icons.photo_camera_outlined,
                      isLoading: _taking,
                      onPressed: ready && !_taking ? _takePicture : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Indicación sobre el visor: dónde ubicar el recibo y que vaya solo. El OCR
/// lee todo el texto de la imagen; otro papel alrededor puede aportar un
/// total que no es el del recibo (docs/07 §7.3).
class ReceiptFrameHint extends StatelessWidget {
  const ReceiptFrameHint({super.key});

  static const String text =
      'Ubica el recibo dentro del marco, sobre una superficie lisa y sin '
      'otros papeles';

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: AppColors.surface),
    );
  }
}

/// Marco de encuadre: cuatro esquinas resaltadas.
class _FramePainter extends CustomPainter {
  const _FramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final frame = Rect.fromLTRB(
      AppSpacing.xxl,
      AppSpacing.xxl,
      size.width - AppSpacing.xxl,
      size.height - AppSpacing.xxl * 2,
    );
    if (frame.width <= 0 || frame.height <= 0) return;
    final paint = Paint()
      ..color = AppColors.surface
      ..strokeWidth = AppSizes.receiptFrameStroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const corner = AppSizes.receiptFrameCorner;
    final path = Path()
      ..moveTo(frame.left, frame.top + corner)
      ..lineTo(frame.left, frame.top)
      ..lineTo(frame.left + corner, frame.top)
      ..moveTo(frame.right - corner, frame.top)
      ..lineTo(frame.right, frame.top)
      ..lineTo(frame.right, frame.top + corner)
      ..moveTo(frame.right, frame.bottom - corner)
      ..lineTo(frame.right, frame.bottom)
      ..lineTo(frame.right - corner, frame.bottom)
      ..moveTo(frame.left + corner, frame.bottom)
      ..lineTo(frame.left, frame.bottom)
      ..lineTo(frame.left, frame.bottom - corner);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_FramePainter oldDelegate) => false;
}
