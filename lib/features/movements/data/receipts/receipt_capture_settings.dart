// Calidad de las fotos de recibos (docs/07 §7.1 y §7.2). Si la medición del
// cifrado en un celular de gama baja sale mal, se baja la resolución aquí:
// ResolutionPreset.high (720p) y 1280 px en la galería.

import 'package:camera/camera.dart';

/// Resolución de la cámara: 1080p, suficiente para que el OCR lea el texto
/// pequeño del recibo.
const ResolutionPreset receiptCaptureResolution = ResolutionPreset.veryHigh;

/// Lado mayor de una imagen elegida de la galería, en píxeles.
const double receiptGalleryMaxSide = 1920;

/// Calidad JPEG de una imagen de la galería al reducirla (0 a 100).
const int receiptGalleryQuality = 85;
