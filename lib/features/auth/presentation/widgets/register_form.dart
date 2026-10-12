import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../register_view_model.dart';

/// Formulario de registro (pantalla 2, fig. 5.3). Al crear la cuenta muestra
/// "Verifica tu correo"; [onGoToLogin] vuelve a la pestaña de inicio de sesión.
class RegisterForm extends ConsumerWidget {
  const RegisterForm({super.key, required this.onGoToLogin});

  final VoidCallback onGoToLogin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(registerViewModelProvider);
    final viewModel = ref.read(registerViewModelProvider.notifier);

    final submittedEmail = state.submittedEmail;
    if (submittedEmail != null) {
      return AppEmptyState(
        icon: Icons.mark_email_read_outlined,
        title: 'Verifica tu correo',
        description:
            'Te enviamos un enlace de verificación a $submittedEmail. '
            'Ábrelo para activar tu cuenta.',
        actionLabel: 'Ir a iniciar sesión',
        onAction: onGoToLogin,
      );
    }

    final requirements = state.requirements;
    void comingSoon() =>
        AppSnackbar.info(context, 'Disponible próximamente');

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label: 'Nombre',
            hint: 'Tu nombre completo',
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
            onChanged: viewModel.setPassword,
          ),
          if (state.showStrength) ...[
            const SizedBox(height: AppSpacing.md),
            AppPasswordStrength(
              strength: state.strength,
              requirements: [
                AppRequirement(
                  label: 'Mínimo 8 caracteres',
                  met: requirements.minLength,
                ),
                AppRequirement(
                  label: 'Una mayúscula',
                  met: requirements.hasUppercase,
                ),
                AppRequirement(
                  label: 'Un número',
                  met: requirements.hasNumber,
                ),
                AppRequirement(
                  label: 'Un símbolo',
                  met: requirements.hasSymbol,
                ),
              ],
            ),
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
