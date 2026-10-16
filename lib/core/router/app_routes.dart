/// Rutas de la aplicación (flujo de navegación, docs/05-diseno-ui.md §5.1).
abstract final class AppRoutes {
  static const String login = '/login';

  /// "Verifica tu correo" después del registro (diagrama 5.1, C2). Recibe el
  /// correo en `extra`, no en la URL.
  static const String verifyEmail = '/verify-email';

  /// Recuperación de contraseña (pantalla 3).
  static const String recoverPassword = '/recover';

  // Pestañas de la barra inferior
  static const String home = '/home';
  static const String reports = '/reports';
  static const String simulator = '/simulator';
  static const String profile = '/profile';

  // Flujo de nuevo gasto, a pantalla completa
  static const String newMovement = '/movements/new';
  static const String confirmMovement = '/movements/confirm';

  /// Edición de un movimiento existente (RF-23), a pantalla completa.
  static const String editMovement = '/movements/:$idParam/edit';

  /// Parámetro de [editMovement] con el identificador del movimiento.
  static const String idParam = 'id';

  /// Ruta de edición del movimiento [id].
  static String editMovementWith(String id) =>
      '/movements/${Uri.encodeComponent(id)}/edit';

  /// Parámetro de [confirmMovement] con el método de registro: photo o manual.
  static const String methodParam = 'method';

  /// Ruta de confirmación con su método de registro.
  static String confirmMovementWith(String method) =>
      Uri(path: confirmMovement, queryParameters: {methodParam: method})
          .toString();

  /// Galería de componentes, solo en modo debug.
  static const String devComponents = '/dev/components';
}
