import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import 'movement_entry_method.dart';

/// Pantalla provisional de confirmación. La real se construye en la Fase 3.
class ConfirmMovementScreen extends StatelessWidget {
  const ConfirmMovementScreen({super.key, required this.method});

  final MovementEntryMethod method;

  void _save(BuildContext context) {
    // El snackbar vive en el ScaffoldMessenger raíz, así que sigue visible en Inicio.
    AppSnackbar.success(context, 'Gasto guardado');
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Volver',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Confirma los datos',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppBanner(
                title: 'Método: ${method.label}',
                description: 'Pantalla provisional de la Fase 2.',
              ),
              const Spacer(),
              AppPrimaryButton(
                label: 'Guardar gasto',
                icon: Icons.description_outlined,
                onPressed: () => _save(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
