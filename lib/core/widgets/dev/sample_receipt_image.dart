import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Recibo de muestra para la galería de componentes, dibujado en memoria:
/// la app no incluye fotos de recibos. Devuelve el PNG y el recuadro de la
/// fila del total, en píxeles. Solo se usa en modo desarrollo.
Future<(Uint8List, Rect)> drawSampleReceipt(TextStyle style) async {
  const width = 360.0;
  const lineHeight = 28.0;
  const lines = [
    ('ÉXITO AV. EL DORADO', ''),
    ('NIT 890.900.608-9', ''),
    ('Leche larga vida x2', '\$8.900'),
    ('Pan tajado', '\$4.500'),
    ('Huevos x30', '\$19.800'),
    ('TOTAL', '\$33.200'),
  ];
  const height = AppSpacing.xxl * 2 + lineHeight * 6;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawRect(
      const Rect.fromLTWH(0, 0, width, height),
      Paint()..color = AppColors.surface,
    );
  Rect? totalRow;
  for (var i = 0; i < lines.length; i++) {
    final (label, amount) = lines[i];
    final top = AppSpacing.xxl + i * lineHeight;
    _paint(canvas, label, style, Offset(AppSpacing.xl, top));
    if (amount.isNotEmpty) {
      _paint(
        canvas,
        amount,
        style,
        Offset(width - AppSpacing.xl, top),
        alignEnd: true,
      );
    }
    if (label == 'TOTAL') {
      totalRow = Rect.fromLTRB(
        AppSpacing.xl,
        top,
        width - AppSpacing.xl,
        top + lineHeight - AppSpacing.xs,
      );
    }
  }

  final image = await recorder.endRecording().toImage(
    width.toInt(),
    height.toInt(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return (data!.buffer.asUint8List(), totalRow!);
}

void _paint(
  Canvas canvas,
  String text,
  TextStyle style,
  Offset at, {
  bool alignEnd = false,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: style.copyWith(color: AppColors.textPrimary),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, alignEnd ? at.translate(-painter.width, 0) : at);
  painter.dispose();
}
