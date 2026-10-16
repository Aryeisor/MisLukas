import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import 'widgets/login_form.dart';
import 'widgets/register_form.dart';

/// Pantalla de inicio de sesión y registro (pantallas 1 y 2, fig. 5.2 y 5.3).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Pestaña activa: 0 = Iniciar sesión, 1 = Registrarse. Es estado de UI.
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.lg),
              const Center(child: _AppLogo()),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'MisLukas',
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Controla tus lukas en un solo lugar',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppSegmentedTabs(
                labels: const ['Iniciar sesión', 'Registrarse'],
                selectedIndex: _tab,
                onChanged: (index) => setState(() => _tab = index),
              ),
              const SizedBox(height: AppSpacing.xl),
              // Cada formulario se desmonta al cambiar de pestaña y su
              // ViewModel (autoDispose) se reinicia con él.
              if (_tab == 0) const LoginForm() else const RegisterForm(),
              if (kDebugMode) ...[
                const SizedBox(height: AppSpacing.xl),
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

/// Ícono de moneda en un recuadro azul claro. Decorativo: el nombre va debajo.
class _AppLogo extends StatelessWidget {
  const _AppLogo();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: AppSizes.iconBoxLg,
        height: AppSizes.iconBoxLg,
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: const Icon(
          Icons.attach_money_rounded,
          size: AppSizes.iconXl,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
