import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import 'movement_entry_method.dart';
import 'new_movement_view_model.dart';

/// Pantalla de Nuevo gasto: elegir el método de registro (pantalla 6, fig. 5.5).
class NewMovementScreen extends ConsumerWidget {
  const NewMovementScreen({super.key});

  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(newMovementViewModelProvider);
    final viewModel = ref.read(newMovementViewModelProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                'Nuevo gasto',
                                style: textTheme.headlineSmall,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '¿Cómo quieres registrarlo?',
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      AppIconButton(
                        icon: Icons.close,
                        tooltip: 'Cerrar',
                        onPressed: () => _close(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SelectableOptionCard(
                    icon: Icons.photo_camera_outlined,
                    title: MovementEntryMethod.photo.label,
                    badge: 'Recomendado',
                    description:
                        'La app extrae el valor y sugiere la categoría '
                        'automáticamente.',
                    selected: selected == MovementEntryMethod.photo,
                    onTap: () => viewModel.select(MovementEntryMethod.photo),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SelectableOptionCard(
                    icon: Icons.edit_outlined,
                    title: MovementEntryMethod.manual.label,
                    description:
                        'Escribe el valor y elige la categoría tú mismo.',
                    selected: selected == MovementEntryMethod.manual,
                    onTap: () => viewModel.select(MovementEntryMethod.manual),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: AppPrimaryButton(
                label: 'Continuar',
                onPressed: () => context.push(
                  AppRoutes.confirmMovementWith(selected.name),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
