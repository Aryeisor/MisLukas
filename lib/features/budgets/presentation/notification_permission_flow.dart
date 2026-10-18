import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/widgets.dart';
import '../data/budgets_providers.dart';
import '../domain/repositories/notification_services.dart';

final notificationPermissionFlowProvider = Provider<NotificationPermissionFlow>(
  (ref) => NotificationPermissionFlow(
    settings: ref.watch(notificationSettingsRepositoryProvider),
    permission: ref.watch(notificationPermissionProvider),
  ),
);

/// Explicación previa del permiso de notificaciones (docs/07 §7.9): se ofrece
/// una sola vez, cuando el usuario guarda un presupuesto, que es cuando las
/// alertas empiezan a tener sentido. Nunca al abrir la app.
class NotificationPermissionFlow {
  const NotificationPermissionFlow({
    required this._settings,
    required this._permission,
  });

  final NotificationSettingsRepository _settings;
  final NotificationPermissionService _permission;

  /// True si hay que mostrar la explicación: nunca se mostró, el interruptor
  /// está activado y el permiso todavía se puede pedir.
  Future<bool> shouldExplain() async {
    if (await _settings.wasExplained()) return false;
    if (!await _settings.isEnabled()) return false;
    return await _permission.status() == NotificationPermissionStatus.denied;
  }

  /// "Permitir": muestra el diálogo del sistema. No se vuelve a explicar,
  /// responda lo que responda.
  Future<NotificationPermissionStatus> allow() async {
    await _settings.markExplained();
    return _permission.request();
  }

  /// "Ahora no": no muestra el diálogo del sistema ni vuelve a preguntar. Se
  /// puede activar desde el Perfil.
  Future<void> decline() => _settings.markExplained();
}

/// Muestra la explicación previa si corresponde. Si el usuario niega el
/// permiso, las alertas se siguen viendo en Inicio.
Future<void> maybeAskNotificationPermission(
  BuildContext context,
  WidgetRef ref,
) async {
  final flow = ref.read(notificationPermissionFlowProvider);
  try {
    if (!await flow.shouldExplain() || !context.mounted) return;
    final allow = await showAppConfirmDialog(
      context,
      title: 'Te avisamos de tus presupuestos',
      message:
          'Te enviaremos una notificación al llegar al 75% y al 100% de un '
          'presupuesto. No mostramos montos.',
      confirmLabel: 'Permitir',
      cancelLabel: 'Ahora no',
    );
    if (allow) {
      await flow.allow();
    } else {
      await flow.decline();
    }
  } catch (_) {
    // Sin permiso las alertas se ven igual dentro de la app.
  }
}
