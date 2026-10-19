import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/widgets.dart';
import '../notification_settings_view_model.dart';

/// Interruptor "Notificaciones de presupuesto" del Perfil (docs/07 §7.4). Si el
/// permiso solo se puede dar en los ajustes del celular, ofrece abrirlos; al
/// volver a la app se revisa otra vez.
class NotificationSettingsTile extends ConsumerStatefulWidget {
  const NotificationSettingsTile({super.key});

  @override
  ConsumerState<NotificationSettingsTile> createState() =>
      _NotificationSettingsTileState();
}

class _NotificationSettingsTileState
    extends ConsumerState<NotificationSettingsTile> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () =>
          ref.read(notificationSettingsViewModelProvider.notifier).refresh(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _toggle(bool on) async {
    final viewModel = ref.read(notificationSettingsViewModelProvider.notifier);
    final needsSettings = await viewModel.toggle(on);
    if (!needsSettings || !mounted) return;
    final open = await showAppConfirmDialog(
      context,
      title: 'Las notificaciones están desactivadas',
      message:
          'Actívalas en Ajustes › Aplicaciones › MisLukas › Notificaciones. '
          'Mientras tanto, las alertas se ven en Inicio.',
      confirmLabel: 'Abrir Ajustes',
      cancelLabel: 'Ahora no',
    );
    if (open) await viewModel.openSettings();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationSettingsViewModelProvider).value;
    return AppSwitchTile(
      title: 'Notificaciones de presupuesto',
      subtitle: state?.description,
      icon: Icons.notifications_outlined,
      value: state?.active ?? false,
      onChanged: state == null ? null : _toggle,
    );
  }
}
