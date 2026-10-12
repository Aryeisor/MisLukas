import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';

/// Pantalla provisional de inicio de sesión. La real se construye en la Fase 3.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'MisLukas',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Spacer(),
              AppPrimaryButton(
                label: 'Entrar (temporal)',
                onPressed: () => context.go(AppRoutes.home),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: AppSpacing.md),
                AppSecondaryButton(
                  label: 'Ver componentes',
                  icon: Icons.widgets_outlined,
                  onPressed: () => context.push(AppRoutes.devComponents),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
