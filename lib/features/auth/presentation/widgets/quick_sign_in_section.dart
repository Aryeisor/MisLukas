import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../app_lock/unlock_screen.dart';
import '../auth_messages.dart';
import '../quick_sign_in_view_model.dart';

/// Otras formas de entrar, debajo de "Iniciar sesión" (pantalla 1, docs/05).
/// Por ahora solo "Ingresar con huella, rostro o PIN"; "Continuar con Google"
/// y "Continuar con Apple" se agregarán a [_options]. Sin opciones ni aviso
/// no ocupa espacio.
class QuickSignInSection extends ConsumerStatefulWidget {
  const QuickSignInSection({super.key});

  static const String deviceLockLabel = 'Ingresar con huella, rostro o PIN';

  @override
  ConsumerState<QuickSignInSection> createState() => _QuickSignInSectionState();
}

class _QuickSignInSectionState extends ConsumerState<QuickSignInSection> {
  late final AppLifecycleListener _lifecycle;

  QuickSignInViewModel get _viewModel =>
      ref.read(quickSignInViewModelProvider.notifier);

  @override
  void initState() {
    super.initState();
    // El bloqueo de pantalla del celular puede cambiar mientras la app está
    // en segundo plano (por ejemplo, en Ajustes).
    _lifecycle = AppLifecycleListener(
      onResume: () => _viewModel.refreshDeviceLock(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _viewModel.refreshDeviceLock();
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  List<Widget> _options(QuickSignInState state) => [
    if (state.available)
      AppSecondaryButton(
        label: QuickSignInSection.deviceLockLabel,
        icon: Icons.fingerprint,
        onPressed: state.busy ? null : _viewModel.signIn,
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quickSignInViewModelProvider);
    final options = _options(state);
    final message = state.message;
    if (options.isEmpty && message == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (message != null) ...[
            _MessageBanner(message),
            if (options.isNotEmpty) const SizedBox(height: AppSpacing.lg),
          ],
          if (options.isNotEmpty) ...[
            const _OrDivider(),
            const SizedBox(height: AppSpacing.lg),
            for (final (index, option) in options.indexed) ...[
              if (index > 0) const SizedBox(height: AppSpacing.sm),
              option,
            ],
          ],
        ],
      ),
    );
  }
}

/// Separador "o" entre el formulario y las otras formas de entrar.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            'o',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner(this.message);

  final QuickSignInMessage message;

  @override
  Widget build(BuildContext context) {
    return switch (message) {
      QuickSignInMessage.canceled => const AppBanner(
        variant: AppBannerVariant.info,
        title: UnlockScreen.canceledMessage,
      ),
      QuickSignInMessage.lockedOut => const AppBanner(
        variant: AppBannerVariant.warning,
        title: UnlockScreen.lockedOutTitle,
        description: UnlockScreen.lockedOutMessage,
      ),
      QuickSignInMessage.failed => const AppBanner(
        variant: AppBannerVariant.error,
        title: UnlockScreen.failedMessage,
      ),
      QuickSignInMessage.sessionExpired => const AppBanner(
        variant: AppBannerVariant.warning,
        icon: Icons.lock_clock_outlined,
        title: sessionExpiredMessage,
      ),
    };
  }
}
