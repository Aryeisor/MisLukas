import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/auth_failure.dart';
import '../auth_messages.dart';
import '../login_view_model.dart';

/// Formulario de inicio de sesión (pantalla 1, fig. 5.2).
class LoginForm extends ConsumerWidget {
  const LoginForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(loginViewModelProvider);
    final viewModel = ref.read(loginViewModelProvider.notifier);

    final failure = state.failure;

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (failure != null) ...[
            AppBanner(
              variant: failure == AuthFailure.rateLimited
                  ? AppBannerVariant.warning
                  : AppBannerVariant.error,
              icon: failure == AuthFailure.rateLimited
                  ? Icons.lock_clock_outlined
                  : null,
              title: authMessageFor(failure),
            ),
            if (failure == AuthFailure.emailNotConfirmed)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () => context.push(
                    AppRoutes.verifyEmail,
                    extra: state.email.trim(),
                  ),
                  child: const Text('Verificar correo'),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Focus(
            onFocusChange: (hasFocus) {
              if (!hasFocus) viewModel.markEmailTouched();
            },
            child: AppTextField(
              label: 'Correo electrónico',
              hint: 'tucorreo@ejemplo.com',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              errorText: state.emailError,
              onChanged: viewModel.setEmail,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: 'Contraseña',
            isPassword: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onChanged: viewModel.setPassword,
            onSubmitted: (_) => viewModel.submit(),
            trailing: TextButton(
              onPressed: () => context.push(AppRoutes.recoverPassword),
              child: const Text('¿Olvidaste tu contraseña?'),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppPrimaryButton(
            label: 'Iniciar sesión',
            isLoading: state.isSubmitting,
            onPressed: state.canSubmit ? viewModel.submit : null,
          ),
          if (state.retrySeconds > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Intenta de nuevo en ${state.retrySeconds} s',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          const _SocialDivider(),
          const SizedBox(height: AppSpacing.lg),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppSecondaryButton(
                  label: 'Continuar con Google',
                  icon: Icons.g_mobiledata,
                  onPressed: null,
                  badge: 'Próximamente',
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppSecondaryButton(
                  label: 'Continuar con Apple',
                  icon: Icons.apple,
                  onPressed: null,
                  badge: 'Próximamente',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Separador "o continúa con".
class _SocialDivider extends StatelessWidget {
  const _SocialDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            'o continúa con',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
