import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/seed/demo_seed.dart';
import '../../sync/sync_controller.dart';
import '../../theme/app_spacing.dart';
import '../../utils/clock.dart';
import '../../utils/date_formatter.dart';
import '../../utils/utils_providers.dart';
import '../widgets.dart';

/// Acciones de datos de demostración: cargarlos, borrar todos los datos y
/// simular otro mes. Solo existen en modo desarrollo; en la versión de
/// publicación no se muestra nada.
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

  /// Cambia el "hoy" de la app y sincroniza, para que corra la continuidad de
  /// presupuestos del mes nuevo.
  void _shiftMonth({required bool advance}) {
    final offset = ref.read(debugMonthOffsetProvider.notifier);
    advance ? offset.advanceMonth() : offset.reset();
    final today = ref.read(clockProvider).today();
    AppSnackbar.info(context, 'La app usa la fecha ${_dayLabel(today)}');
    ref.read(syncControllerProvider.notifier).syncNow().ignore();
  }

  static String _dayLabel(DateTime day) =>
      '${day.day} de ${DateLabels.monthName(day)} de ${day.year}';

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(demoToolsEnabledProvider)) return const SizedBox.shrink();
    final offset = ref.watch(debugMonthOffsetProvider);
    final today = ref.watch(clockProvider).today();

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
        const SizedBox(height: AppSpacing.lg),
        AppBanner(
          variant: offset == 0
              ? AppBannerVariant.info
              : AppBannerVariant.warning,
          title: offset == 0
              ? 'Fecha real: ${_dayLabel(today)}'
              : 'Fecha simulada: ${_dayLabel(today)}',
          description:
              'Úsala solo con una cuenta de prueba: lo que guardes queda '
              'con fechas adelantadas.',
        ),
        const SizedBox(height: AppSpacing.sm),
        AppSecondaryButton(
          label: 'Adelantar un mes',
          icon: Icons.fast_forward_outlined,
          onPressed: () => _shiftMonth(advance: true),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppSecondaryButton(
          label: 'Volver a la fecha real',
          icon: Icons.restore,
          onPressed: offset == 0 ? null : () => _shiftMonth(advance: false),
        ),
      ],
    );
  }
}
