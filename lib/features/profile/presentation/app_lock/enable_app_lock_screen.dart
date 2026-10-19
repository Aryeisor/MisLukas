import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/widgets/auth_flow_scaffold.dart';
import 'enable_app_lock_view_model.dart';

/// Activar el bloqueo desde el Perfil: la contraseña de la cuenta y luego el
/// diálogo del sistema. Al terminar vuelve al Perfil.
class EnableAppLockScreen extends ConsumerWidget {
  const EnableAppLockScreen({super.key});

  static const String enabledMessage = 'Ingreso con huella, rostro o PIN activado';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(enableAppLockViewModelProvider);
    final viewModel = ref.read(enableAppLockViewModelProvider.notifier);
    final confirming = state.step == EnableAppLockStep.confirmDevice;

    ref.listen(enableAppLockViewModelProvider.select((s) => s.step), (_, step) {
      if (step != EnableAppLockStep.done) return;
      AppSnackbar.success(context, enabledMessage);
      if (context.canPop()) context.pop();
    });

    return AuthFlowScaffold(
      title: 'Ingresar con huella, rostro o PIN',
      description:
          'MisLukas te pedirá tu huella, rostro o PIN del celular al '
          'abrirla y cuando vuelvas después de 5 minutos. Al cerrar sesión, '
          'podrás volver a entrar sin tu contraseña. Primero confirma tu '
          'contraseña de MisLukas.',
      bottom: AppPrimaryButton(
        label: state.isSubmitting
            ? 'Verificando…'
            : confirming
            ? 'Activar'
            : 'Continuar',
        icon: Icons.lock_outline,
        onPressed: state.canSubmit ? viewModel.submit : null,
      ),
      children: [
        if (confirming) ...[
          const AppBanner(
            variant: AppBannerVariant.success,
            title: 'Contraseña verificada',
            description: 'Confirma con el bloqueo de tu celular.',
          ),
          if (state.error case final error?) ...[
            const SizedBox(height: AppSpacing.lg),
            AppBanner(variant: AppBannerVariant.warning, title: error.message),
          ],
        ] else
          AppTextField(
            label: 'Contraseña',
            isPassword: true,
            enabled: !state.isSubmitting,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            errorText: state.error?.message,
            onChanged: viewModel.setPassword,
            onSubmitted: (_) => viewModel.submit(),
          ),
      ],
    );
  }
}
