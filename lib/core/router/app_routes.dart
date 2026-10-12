/// Rutas de la aplicación (flujo de navegación, docs/05-diseno-ui.md §5.1).
abstract final class AppRoutes {
  static const String login = '/login';

  // Pestañas de la barra inferior
  static const String home = '/home';
  static const String reports = '/reports';
  static const String simulator = '/simulator';
  static const String profile = '/profile';

  // Flujo de nuevo gasto, a pantalla completa
  static const String newMovement = '/movements/new';
  static const String confirmMovement = '/movements/confirm';

  /// Parámetro de [confirmMovement] con el método de registro: photo o manual.
  static const String methodParam = 'method';

  /// Ruta de confirmación con su método de registro.
  static String confirmMovementWith(String method) =>
      Uri(path: confirmMovement, queryParameters: {methodParam: method})
          .toString();

  /// Galería de componentes, solo en modo debug.
  static const String devComponents = '/dev/components';
}
