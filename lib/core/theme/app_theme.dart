import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

/// Tema visual de MisLukas (guía de estilo, docs/05-diseno-ui.md §5.4).
abstract final class AppTheme {
  static const String _fontFamily = 'DMSans';

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: AppColors.surface,
      error: AppColors.error,
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: _fontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: _textTheme,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.action,
          foregroundColor: AppColors.surface,
          disabledBackgroundColor: AppColors.disabled,
          disabledForegroundColor: AppColors.surface,
          minimumSize: const Size.fromHeight(52),
          shape: shape,
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          minimumSize: const Size(
            AppSpacing.minTouchTarget,
            AppSpacing.minTouchTarget,
          ),
          shape: shape,
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.all(AppSpacing.lg),
        hintStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
        border: _inputBorder(AppColors.border),
        enabledBorder: _inputBorder(AppColors.border),
        disabledBorder: _inputBorder(AppColors.border),
        focusedBorder: _inputBorder(AppColors.primary, width: 1.5),
        errorBorder: _inputBorder(AppColors.error),
        focusedErrorBorder: _inputBorder(AppColors.error, width: 1.5),
        errorStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 12,
          color: AppColors.error,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }

  static const TextTheme _textTheme = TextTheme(
    // Montos principales
    headlineLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),
    // Títulos de pantalla
    headlineSmall: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),
    // Títulos de sección
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    bodyLarge: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimary,
    ),
    // Fechas, categorías y notas
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
    ),
    // Etiquetas de campo en mayúsculas
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
      color: AppColors.textSecondary,
    ),
  );

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
