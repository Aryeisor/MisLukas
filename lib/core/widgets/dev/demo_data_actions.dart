import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/seed/demo_seed.dart';
import '../../theme/app_spacing.dart';
import '../widgets.dart';

/// Acciones de datos de demostración: cargarlos y borrar todos los datos.
/// Solo existen en modo desarrollo; en la versión de publicación no se
/// muestra nada.
class DemoDataActions extends ConsumerStatefulWidget {
  const DemoDataActions({super.key});

  @override
  ConsumerState<DemoDataActions> createState() => _DemoDataActionsState();
}

class _DemoDataActionsState extends ConsumerState<DemoDataActions> {
  bool _busy = false;

  Future<void> _run(
    Future<void> Function(DemoSeed seed) action,
    String successMessage,
  ) async {
    setState(() => _busy = true);
    try {
      await action(ref.read(demoSeedProvider));
      if (mounted) AppSnackbar.success(context, successMessage);
    } catch (_) {
      if (mounted) {
        AppSnackbar.error(context, 'No pudimos completar la acción.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() =>
      _run((seed) => seed.load(), 'Datos de demostración cargados');

  Future<void> _clear() async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: '¿Borrar todos los datos?',
      message:
          'Se eliminan todos los movimientos y presupuestos de este '
          'dispositivo. Esta acción no se puede deshacer.',
      confirmLabel: 'Borrar',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _run((seed) => seed.clearAll(), 'Se borraron todos los datos');
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(demoToolsEnabledProvider)) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionHeader(title: 'Herramientas de desarrollo'),
        const SizedBox(height: AppSpacing.sm),
        AppSecondaryButton(
          label: 'Cargar datos de demostración',
          icon: Icons.dataset_outlined,
          onPressed: _busy ? null : _load,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppSecondaryButton(
          label: 'Borrar todos los datos',
          icon: Icons.delete_sweep_outlined,
          destructive: true,
          onPressed: _busy ? null : _clear,
        ),
      ],
    );
  }
}
