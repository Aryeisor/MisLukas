import 'package:flutter/material.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_spacing.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/currency_formatter.dart';

class MisLukasApp extends StatelessWidget {
  const MisLukasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MisLukas',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _ThemePreview(),
    );
  }
}

// Pantalla temporal para revisar el tema. Se elimina en la Fase 2,
// cuando se configure go_router con las pantallas reales.
class _ThemePreview extends StatelessWidget {
  const _ThemePreview();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            Text('Hola, Camila 👋', style: textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              CurrencyFormatter.format(1874320),
              style: textTheme.headlineLarge,
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('CORREO ELECTRÓNICO', style: textTheme.labelSmall),
            const SizedBox(height: AppSpacing.sm),
            const TextField(
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(hintText: 'tucorreo@ejemplo.com'),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: () {},
              child: const Text('Iniciar sesión'),
            ),
            const SizedBox(height: AppSpacing.md),
            const FilledButton(
              onPressed: null,
              child: Text('Crear cuenta'),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: () {},
              child: const Text('Continuar con Google'),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              CurrencyFormatter.signed(87400, isIncome: false),
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              CurrencyFormatter.signed(3800000, isIncome: true),
              style: textTheme.bodyLarge?.copyWith(color: AppColors.success),
            ),
          ],
        ),
      ),
    );
  }
}
