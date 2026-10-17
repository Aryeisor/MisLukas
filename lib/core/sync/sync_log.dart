import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Registro de la sincronización, solo en modo desarrollo. Recibe únicamente
/// datos técnicos: tabla, operación, código de error e intento. Nunca ids,
/// montos, textos, correos ni tokens (docs/08 §8.8.5).
void syncLog(String table, String event, {String? code, int? attempt}) {
  if (!kDebugMode) return;
  final details = [
    if (code != null) 'código $code',
    if (attempt != null) 'intento $attempt',
  ].join(', ');
  developer.log(
    details.isEmpty ? '$table: $event' : '$table: $event ($details)',
    name: 'mislukas.sync',
  );
}
