import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import 'auth_messages.dart';
import 'recover_password_view_model.dart';
import 'widgets/auth_flow_scaffold.dart';
import 'widgets/password_strength_section.dart';

/// Recuperar contraseña (pantalla 3, docs/05 §5.2): correo, código de
/// 6 dígitos, contraseña nueva y confirmación (RF-08 a RF-10).
class RecoverPasswordScreen extends ConsumerWidget {
  const RecoverPasswordScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recoverPasswordViewModelProvider);
    final viewModel = ref.read(recoverPasswordViewModelProvider.notifier);

    // Salida del usuario (Volver o atrás del sistema): cierra la sesión
    // temporal si el código ya se verificó y vuelve al login, de donde se
    // abrió la recuperación. Mientras se espera al servidor no se sale.
    Future<void> exit() async {
      if (state.isSubmitting) return;
      await viewModel.cancel();
      if (context.mounted) context.go(AppRoutes.login);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) exit();
      },
      child: switch (state.step) {
        RecoverStep.email => _EmailStep(
          state: state,
          viewModel: viewModel,
          onBack: exit,
        ),
        RecoverStep.code => _CodeStep(
          state: state,
          viewModel: viewModel,
          onBack: exit,
        ),
        RecoverStep.newPassword => _PasswordStep(
          state: state,
          viewModel: viewModel,
          onBack: exit,
        ),
        RecoverStep.done => _DoneStep(onBack: exit),
      },
    );
  }
}

class _EmailStep extends StatelessWidget {
  const _EmailStep({
    required this.state,
    required this.viewModel,
    required this.onBack,
  });

  final RecoverPasswordState state;
  final RecoverPasswordViewModel viewModel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final failure = state.failure;
    return AuthFlowScaffold(
      stepLabel: 'Paso 1 de 3',
      onBack: onBack,
      title: 'Recupera tu contraseña',
      description: 'Escribe el correo de tu cuenta y te enviaremos un código.',
      bottom: AppPrimaryButton(
        label: 'Enviar código',
        isLoading: state.isSubmitting,
        onPressed: state.canSendCode ? viewModel.sendCode : null,
      ),
      children: [
        if (failure != null) ...[
          AppBanner(
            variant: AppBannerVariant.error,
            title: authMessageFor(failure),
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
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            errorText: state.emailError,
            onChanged: viewModel.setEmail,
            onSubmitted: (_) => viewModel.sendCode(),
          ),
        ),
      ],
    );
  }
}

class _CodeStep extends StatelessWidget {
  const _CodeStep({
    required this.state,
    required this.viewModel,
    required this.onBack,
  });

  final RecoverPasswordState state;
  final RecoverPasswordViewModel viewModel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return AuthFlowScaffold(
      stepLabel: 'Paso 2 de 3',
      onBack: onBack,
      title: 'Ingresa el código',
      description: recoverySentMessage,
      bottom: AppPrimaryButton(
        label: 'Verificar',
        isLoading: state.isSubmitting,
        onPressed: state.canVerifyCode ? viewModel.verifyCode : null,
      ),
      children: [
        AppCodeField(
          // Un código nuevo vacía el campo.
          key: ValueKey(state.codeRevision),
          enabled: !state.isSubmitting && !state.codeLocked,
          errorText: state.codeError,
          onChanged: viewModel.setCode,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'El código vence en 10 minutos y sirve una sola vez.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        ResendCodeButton(
          secondsLeft: state.resendSeconds,
          isLoading: state.isSubmitting,
          onPressed: viewModel.resendCode,
        ),
      ],
    );
  }
}

class _PasswordStep extends StatelessWidget {
  const _PasswordStep({
    required this.state,
    required this.viewModel,
    required this.onBack,
  });

  final RecoverPasswordState state;
  final RecoverPasswordViewModel viewModel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final failure = state.failure;
    return AuthFlowScaffold(
      stepLabel: 'Paso 3 de 3',
      onBack: onBack,
      title: 'Crea tu nueva contraseña',
      bottom: AppPrimaryButton(
        label: 'Guardar contraseña',
        isLoading: state.isSubmitting,
        onPressed: state.canSavePassword ? viewModel.savePassword : null,
      ),
      children: [
        if (failure != null) ...[
          AppBanner(
            variant: AppBannerVariant.error,
            title: authMessageFor(failure),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: 'Nueva contraseña',
                isPassword: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                errorText: state.passwordError,
                onChanged: viewModel.setPassword,
              ),
              if (state.password.isNotEmpty) ...[
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
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Usa al menos $passwordMinLength caracteres; se recomiendan 12 o más.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _DoneStep extends StatelessWidget {
  const _DoneStep({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return AuthFlowScaffold(
      title: 'Contraseña actualizada',
      onBack: onBack,
      bottom: AppPrimaryButton(label: 'Ir a iniciar sesión', onPressed: onBack),
      children: const [
        AppBanner(
          variant: AppBannerVariant.success,
          title: 'Actualizamos tu contraseña',
          description:
              'Por seguridad cerramos tu sesión en todos tus dispositivos. '
              'Inicia sesión con tu nueva contraseña.',
        ),
      ],
    );
  }
}
