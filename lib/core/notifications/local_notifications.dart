import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Canal de Android de las alertas de presupuesto.
const String budgetAlertsChannelId = 'alertas_presupuesto';

/// Ícono monocromo de la barra de estado (res/drawable/ic_stat_alerta.xml).
const String notificationIcon = 'ic_stat_alerta';

/// Notificaciones locales del sistema (docs/07 §7.4). No se programan: solo se
/// muestran mientras la app corre, así que no hay alarmas ni trabajo en
/// segundo plano.
///
/// Sin [initialize] (pruebas o fallo del plugin) no muestra nada.
class LocalNotifications {
  LocalNotifications({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<String> _taps = StreamController.broadcast();
  bool _initialized = false;
  String? _launchPayload;

  /// Se llama en main() antes de runApp. El permiso no se pide aquí: lo pide
  /// permission_handler cuando tiene sentido (docs/07 §7.9).
  Future<void> initialize() async {
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings(notificationIcon),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null) _taps.add(payload);
        },
      );
      _initialized = true;
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        _launchPayload = launch!.notificationResponse?.payload;
      }
    } catch (_) {
      // Sin notificaciones la app funciona igual: las alertas se ven en Inicio.
    }
  }

  /// Payload de la notificación que abrió la app, una sola vez.
  String? takeLaunchPayload() {
    final payload = _launchPayload;
    _launchPayload = null;
    return payload;
  }

  /// Payloads de las notificaciones tocadas con la app abierta.
  Stream<String> get taps => _taps.stream;

  /// Muestra una notificación privada: en la pantalla de bloqueo segura
  /// Android oculta el texto.
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (!_initialized) return;
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      payload: payload,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          budgetAlertsChannelId,
          'Alertas de presupuesto',
          channelDescription:
              'Avisos al llegar al 75% y al 100% de un presupuesto',
          icon: notificationIcon,
          visibility: NotificationVisibility.private,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> cancelAll() async {
    if (!_initialized) return;
    await _plugin.cancelAll();
  }
}

/// Se reemplaza en main() con la instancia ya inicializada.
final localNotificationsProvider = Provider<LocalNotifications>(
  (ref) => LocalNotifications(),
);
