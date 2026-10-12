import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';

/// Pantalla provisional de inicio. La real se construye en la Fase 3.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Inicio', style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              AppPrimaryButton(
                label: 'Nuevo gasto',
                icon: Icons.add,
                onPressed: () => context.push(AppRoutes.newMovement),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
