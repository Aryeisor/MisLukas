import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';

/// Estructura de las pantallas de verificación y recuperación: botón Volver,
/// paso opcional ("Paso 1 de 3"), título, descripción, contenido desplazable
/// y la acción principal fija abajo.
class AuthFlowScaffold extends StatelessWidget {
  const AuthFlowScaffold({
    super.key,
    required this.title,
    required this.children,
    this.description,
    this.stepLabel,
    this.bottom,
    this.onBack,
  });

  final String title;
  final String? description;
  final String? stepLabel;
  final List<Widget> children;

  /// Acción principal abajo, por ejemplo [AppPrimaryButton].
  final Widget? bottom;

  /// Reemplaza el comportamiento de Volver: cerrar la pantalla o ir al login.
  final VoidCallback? onBack;

  void _back(BuildContext context) {
    if (onBack != null) return onBack!();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: AppIconButton(
                      icon: Icons.arrow_back,
                      tooltip: 'Volver',
                      onPressed: () => _back(context),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (stepLabel != null) ...[
                    Text(stepLabel!, style: textTheme.bodySmall),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  Semantics(
                    header: true,
                    child: Text(title, style: textTheme.headlineSmall),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(description!, style: textTheme.bodyMedium),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  ...children,
                ],
              ),
            ),
            if (bottom != null)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: bottom,
              ),
          ],
        ),
      ),
    );
  }
}

/// Enlace "Reenviar código" con la espera restante.
class ResendCodeButton extends StatelessWidget {
  const ResendCodeButton({
    super.key,
    required this.secondsLeft,
    required this.onPressed,
    this.isLoading = false,
  });

  final int secondsLeft;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final waiting = secondsLeft > 0;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton(
        onPressed: waiting || isLoading ? null : onPressed,
        child: Text(
          waiting ? 'Reenviar código en $secondsLeft s' : 'Reenviar código',
        ),
      ),
    );
  }
}
