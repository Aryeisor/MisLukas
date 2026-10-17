import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/widgets.dart';
import '../auth_messages.dart';
import '../register_view_model.dart';
import 'password_strength_section.dart';

/// Formulario de registro (pantalla 2, fig. 5.3). Al crear la cuenta abre
/// "Verifica tu correo".
class RegisterForm extends ConsumerWidget {
  const RegisterForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(registerViewModelProvider);
    final viewModel = ref.read(registerViewModelProvider.notifier);

    ref.listen(registerViewModelProvider.select((s) => s.submittedEmail), (
      _,
      email,
    ) {
      if (email != null) context.push(AppRoutes.verifyEmail, extra: email);
    });

    final failure = state.failure;
    void comingSoon() => AppSnackbar.info(context, 'Disponible próximamente');

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (failure != null) ...[
            AppBanner(
              variant: AppBannerVariant.error,
              title: authMessageFor(failure),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          AppTextField(
            label: 'Nombre',
            hint: 'Tu nombre completo',
            maxLength: nameMaxLength,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            onChanged: viewModel.setName,
          ),
          const SizedBox(height: AppSpacing.lg),
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
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            errorText: state.passwordError,
            onChanged: viewModel.setPassword,
          ),
          if (state.showStrength) ...[
            const SizedBox(height: AppSpacing.md),
            PasswordStrengthSection(password: state.password),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: 'Confirmar contraseña',
            isPassword: true,
            textInputAction: TextInputAction.done,
            errorText: state.confirmError,
            onChanged: viewModel.setConfirmPassword,
          ),
          const SizedBox(height: AppSpacing.md),
          AppCheckboxTile(
            value: state.acceptedTerms,
            onChanged: viewModel.setAcceptedTerms,
            segments: [
              const AppTextSegment('Acepto los '),
              AppTextSegment('Términos', onTap: comingSoon),
              const AppTextSegment(' y la '),
              AppTextSegment(
                'Política de tratamiento de datos personales',
                onTap: comingSoon,
              ),
              const AppTextSegment(' (Ley 1581 de 2012)'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppPrimaryButton(
            label: 'Crear cuenta',
            isLoading: state.isSubmitting,
            onPressed: state.canSubmit ? viewModel.submit : null,
          ),
        ],
      ),
    );
  }
}
