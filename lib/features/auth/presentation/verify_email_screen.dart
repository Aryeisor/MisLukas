import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import 'auth_messages.dart';
import 'verify_email_view_model.dart';
import 'widgets/auth_flow_scaffold.dart';

/// "Verifica tu correo" (diagrama 5.1, C2): el usuario escribe el código de
/// 6 dígitos que le llegó al registrarse (RF-04). Al verificar, la sesión se
/// inicia y el router lleva a Inicio.
class VerifyEmailScreen extends ConsumerWidget {
  const VerifyEmailScreen({super.key, required this.email});

  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = verifyEmailViewModelProvider(email);
    final state = ref.watch(provider);
    final viewModel = ref.read(provider.notifier);

    ref.listen(provider.select((s) => s.verified), (_, verified) {
      if (verified) AppSnackbar.success(context, 'Cuenta creada');
    });
    ref.listen(provider.select((s) => s.resent), (_, resent) {
      if (resent) AppSnackbar.info(context, 'Te enviamos un código nuevo');
    });

    final failure = state.failure;

    return AuthFlowScaffold(
      title: 'Verifica tu correo',
      // Sin el correo en pantalla: puede quedar en capturas o grabaciones.
      description:
          'Te enviamos un código de $otpLength dígitos a tu correo. '
          'Escríbelo para activar tu cuenta.',
      bottom: AppPrimaryButton(
        label: 'Verificar',
        isLoading: state.isSubmitting,
        onPressed: state.canSubmit ? viewModel.submit : null,
      ),
      children: [
        AppCodeField(
          // Al reenviar, el campo se vacía.
          key: ValueKey(state.resent),
          enabled: !state.isSubmitting,
          errorText: failure == null ? null : authMessageFor(failure),
          onChanged: viewModel.setCode,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Si no lo ves, revisa la carpeta de spam.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        ResendCodeButton(
          secondsLeft: state.resendSeconds,
          isLoading: state.isResending,
          onPressed: viewModel.resend,
        ),
      ],
    );
  }
}
