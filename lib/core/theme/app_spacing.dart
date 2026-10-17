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

/// Tamaños de íconos, contenedores y trazos de los componentes.
abstract final class AppSizes {
  // Íconos
  static const double iconXs = 10;
  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;
  static const double iconXl = 32;

  /// Cuadrado del ícono de categoría y de las tarjetas seleccionables.
  static const double iconBox = 40;

  /// Círculo del ícono en los estados vacíos.
  static const double iconBoxLg = 64;

  /// Círculos decorativos de la tarjeta de resumen.
  static const double decorCircleLg = 160;
  static const double decorCircleSm = 96;

  /// Alto de las barras de progreso (fortaleza de contraseña).
  static const double progressBarHeight = 4;

  /// Avatar con iniciales del perfil.
  static const double avatar = 72;

  /// Alto de cada casilla del código de verificación.
  static const double codeBoxHeight = 56;

  // Gráficos
  /// Diámetro de la dona de Reportes.
  static const double donutSize = 120;

  /// Grosor del anillo de la dona.
  static const double donutStroke = 22;

  /// Alto del área de barras del gráfico año a año.
  static const double chartHeight = 140;

  /// Alto de la barra de variación mensual.
  static const double variationBarHeight = 8;

  /// Punto o cuadro de color de las leyendas.
  static const double legendDot = 10;

  // Trazos
  static const double borderWidth = 1;
  static const double borderWidthSelected = 1.5;
  static const double progressStroke = 2;
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
