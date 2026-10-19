import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/movements/data/movements_providers.dart';
import '../../theme/app_spacing.dart';
import '../widgets.dart';

/// La medición existe en modo desarrollo y en `--profile` (donde se mide el
/// rendimiento real), nunca en la versión de publicación.
final receiptBenchmarkEnabledProvider = Provider<bool>((ref) => !kReleaseMode);

/// "Medir cifrado de recibos": cifra y descifra 10 veces 1 MB de bytes
/// aleatorios con el cifrado de las imágenes (AES-GCM nativo) y muestra la
/// mediana (docs/07 §7.5). Nunca usa una foto real ni escribe en logs.
class ReceiptCipherBenchmarkAction extends ConsumerStatefulWidget {
  const ReceiptCipherBenchmarkAction({super.key});

  /// Tamaño de la imagen de prueba: una foto de recibo de 1080p pesa entre
  /// 300 KB y 1 MB.
  static const int sampleBytes = 1024 * 1024;

  static const int rounds = 10;

  @override
  ConsumerState<ReceiptCipherBenchmarkAction> createState() =>
      _ReceiptCipherBenchmarkActionState();
}

class _ReceiptCipherBenchmarkActionState
    extends ConsumerState<ReceiptCipherBenchmarkAction> {
  bool _running = false;

  Future<void> _measure() async {
    setState(() => _running = true);
    try {
      final cipher = ref.read(receiptCipherProvider);
      final random = Random();
      final sample = Uint8List.fromList(
        List.generate(
          ReceiptCipherBenchmarkAction.sampleBytes,
          (_) => random.nextInt(256),
        ),
      );
      const aad = [0x62, 0x65, 0x6e, 0x63, 0x68]; // "bench"

      // Una vuelta para cargar la clave y el código nativo.
      await cipher.decrypt(
        await cipher.encrypt(sample, associatedData: aad),
        associatedData: aad,
      );

      final encryptTimes = <int>[];
      final decryptTimes = <int>[];
      for (var i = 0; i < ReceiptCipherBenchmarkAction.rounds; i++) {
        final watch = Stopwatch()..start();
        final sealed = await cipher.encrypt(sample, associatedData: aad);
        encryptTimes.add(watch.elapsedMilliseconds);
        watch
          ..reset()
          ..start();
        await cipher.decrypt(sealed, associatedData: aad);
        decryptTimes.add(watch.elapsedMilliseconds);
      }
      if (!mounted) return;
      AppSnackbar.info(
        context,
        'Cifrar: ${_median(encryptTimes)} ms · '
        'Descifrar: ${_median(decryptTimes)} ms '
        '(mediana de ${ReceiptCipherBenchmarkAction.rounds}, 1 MB)',
      );
    } catch (_) {
      if (mounted) AppSnackbar.error(context, 'No pudimos medir el cifrado.');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  static int _median(List<int> values) {
    final sorted = [...values]..sort();
    return sorted[sorted.length ~/ 2];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionHeader(title: 'Rendimiento'),
        const SizedBox(height: AppSpacing.sm),
        AppSecondaryButton(
          label: _running ? 'Midiendo…' : 'Medir cifrado de recibos',
          icon: Icons.speed_outlined,
          onPressed: _running ? null : _measure,
        ),
      ],
    );
  }
}
