import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../budgets/data/budgets_providers.dart';
import '../../budgets/domain/repositories/notification_services.dart';

/// Interruptor de notificaciones de presupuesto del Perfil.
class NotificationSettingsState {
  const NotificationSettingsState({
    required this.enabled,
    required this.permission,
  });

  /// Interruptor propio de la app.
  final bool enabled;
  final NotificationPermissionStatus permission;

  /// Las notificaciones llegan solo con el interruptor y el permiso.
  bool get active =>
      enabled && permission == NotificationPermissionStatus.granted;

  /// El permiso solo se puede dar en los ajustes del celular.
  bool get blockedBySystem =>
      permission == NotificationPermissionStatus.permanentlyDenied ||
      permission == NotificationPermissionStatus.restricted;

  String get description {
    if (!enabled) return 'Desactivadas. Las alertas se ven en Inicio';
    if (active) return 'Te avisamos al 75% y al 100%';
    if (blockedBySystem) return 'Desactivadas en los ajustes del celular';
    return 'Permite las notificaciones del celular';
  }
}

final notificationSettingsViewModelProvider =
    AsyncNotifierProvider.autoDispose<
      NotificationSettingsViewModel,
      NotificationSettingsState
    >(NotificationSettingsViewModel.new);

class NotificationSettingsViewModel
    extends AsyncNotifier<NotificationSettingsState> {
  @override
  Future<NotificationSettingsState> build() => _load();

  Future<NotificationSettingsState> _load() async {
    final enabled = await ref
        .read(notificationSettingsRepositoryProvider)
        .isEnabled();
    final permission = await ref.read(notificationPermissionProvider).status();
    return NotificationSettingsState(enabled: enabled, permission: permission);
  }

  /// Vuelve a leer el permiso (al volver de los ajustes del celular).
  Future<void> refresh() async {
    try {
      final next = await _load();
      if (ref.mounted) state = AsyncData(next);
    } catch (_) {
      // Se mantiene lo último conocido.
    }
  }

  /// Activa o desactiva las notificaciones. Al activarlas pide el permiso si
  /// todavía se puede. Devuelve true si el permiso solo se puede dar en los
  /// ajustes del celular.
  Future<bool> toggle(bool on) async {
    final settings = ref.read(notificationSettingsRepositoryProvider);
    final permission = ref.read(notificationPermissionProvider);
    try {
      await settings.setEnabled(on);
      var status = await permission.status();
      if (on && status == NotificationPermissionStatus.denied) {
        // Aquí el usuario lo pidió: no hace falta la explicación previa.
        await settings.markExplained();
        status = await permission.request();
      }
      if (ref.mounted) {
        state = AsyncData(
          NotificationSettingsState(enabled: on, permission: status),
        );
      }
      return on &&
          (status == NotificationPermissionStatus.permanentlyDenied ||
              status == NotificationPermissionStatus.restricted);
    } catch (_) {
      await refresh();
      return false;
    }
  }

  Future<void> openSettings() async {
    try {
      await ref.read(notificationPermissionProvider).openSettings();
    } catch (_) {
      // Sin ajustes, las alertas se siguen viendo en Inicio.
    }
  }
}
