import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import 'movement_entry_method.dart';

/// Pantalla provisional de nuevo gasto. La real se construye en la Fase 3.
class NewMovementScreen extends StatelessWidget {
  const NewMovementScreen({super.key});

  void _open(BuildContext context, MovementEntryMethod method) {
    context.push(AppRoutes.confirmMovementWith(method.name));
  }

  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
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
                  Expanded(
                    child: Text(
                      'Nuevo gasto',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    icon: const Icon(Icons.close),
                    onPressed: () => _close(context),
                  ),
                ],
              ),
              const Spacer(),
              AppPrimaryButton(
                label: MovementEntryMethod.photo.label,
                icon: Icons.photo_camera_outlined,
                onPressed: () => _open(context, MovementEntryMethod.photo),
              ),
              const SizedBox(height: AppSpacing.md),
              AppSecondaryButton(
                label: MovementEntryMethod.manual.label,
                icon: Icons.edit_outlined,
                onPressed: () => _open(context, MovementEntryMethod.manual),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
