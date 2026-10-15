import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'clock.dart';
import 'id_generator.dart';

/// Reloj de la app. En pruebas se sobrescribe con un [FixedClock].
final clockProvider = Provider<Clock>((ref) => const SystemClock());

/// Generador de identificadores UUID v4.
final idGeneratorProvider = Provider<IdGenerator>(
  (ref) => const UuidIdGenerator(),
);
