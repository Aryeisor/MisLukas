/// Espaciados de la retícula base de 8 px (guía de estilo §5.4.4).
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Margen lateral de las pantallas.
  static const double screenPadding = 20;

  /// Área táctil mínima de los elementos interactivos.
  static const double minTouchTarget = 48;
}

/// Radios de los bordes redondeados (guía de estilo §5.4.4).
abstract final class AppRadius {
  /// Chips.
  static const double sm = 8;

  /// Tarjetas, botones y campos.
  static const double md = 12;

  /// Tarjeta principal.
  static const double lg = 16;
}
