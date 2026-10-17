import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/widgets/auth_flow_scaffold.dart';
import 'delete_account_view_model.dart';

/// Eliminar la cuenta (RF-48, docs/08 §8.9.4). Se llega desde el Perfil
/// después de confirmar en un diálogo que la acción es permanente. Pide la
/// contraseña por seguridad. Al terminar, el router lleva al login.
class DeleteAccountScreen extends ConsumerWidget {
  const DeleteAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(deleteAccountViewModelProvider);
    final viewModel = ref.read(deleteAccountViewModelProvider.notifier);
    final retrying = state.step == DeleteAccountStep.retry;

    return AuthFlowScaffold(
      title: 'Eliminar mi cuenta',
      description:
          'Se borrarán para siempre tu cuenta, tus movimientos, presupuestos y '
          'recibos, en este celular y en la nube.',
      bottom: AppSecondaryButton(
        label: state.isSubmitting
            ? 'Eliminando…'
            : retrying
            ? 'Reintentar'
            : 'Eliminar mi cuenta',
        icon: retrying ? Icons.refresh : Icons.delete_forever_outlined,
        destructive: true,
        onPressed: state.canSubmit ? viewModel.submit : null,
      ),
      children: [
        const AppBanner(
          variant: AppBannerVariant.warning,
          title: 'Esta acción no se puede deshacer',
          description:
              'Lo que no hayas sincronizado también se perderá. Necesitas '
              'conexión a internet.',
        ),
        const SizedBox(height: AppSpacing.xl),
        if (retrying)
          AppBanner(
            variant: AppBannerVariant.error,
            title: 'La eliminación no terminó',
            description: state.errorMessage,
          )
        else
          AppTextField(
            label: 'Contraseña',
            isPassword: true,
            enabled: !state.isSubmitting,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            errorText: state.errorMessage,
            onChanged: viewModel.setPassword,
            onSubmitted: (_) => viewModel.submit(),
          ),
      ],
    );
  }
}
