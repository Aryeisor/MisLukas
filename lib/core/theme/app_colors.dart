import 'package:flutter/material.dart';

/// Paleta de colores de MisLukas (guía de estilo, docs/05-diseno-ui.md §5.4.1).
abstract final class AppColors {
  // Marca y acción
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryLight = Color(0xFFEFF6FF);
  static const Color action = Color(0xFF111827);

  // Superficies
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5E7EB);
  static const Color disabled = Color(0xFFD1D5DB);

  // Texto
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);

  // Estados
  static const Color success = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color error = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color warningBackground = Color(0xFFFEF9C3);
  static const Color warningBorder = Color(0xFFFDE68A);
  static const Color warningText = Color(0xFF854D0E);

  // Categorías
  static const Color categoryMercado = Color(0xFF2563EB);
  static const Color categoryTransporte = Color(0xFFF59E0B);
  static const Color categoryOcio = Color(0xFF8B5CF6);
  static const Color categoryServicios = Color(0xFF0D9488);
  // Definido en la Fase 1: la guía 5.4.1 no incluía un color para Restaurantes.
  // Se eligió rosa para diferenciarlo del naranja de Transporte.
  static const Color categoryRestaurantes = Color(0xFFDB2777);
  static const Color categoryOtros = Color(0xFFF87171);
  static const Color categoryIngreso = Color(0xFF16A34A);
}
