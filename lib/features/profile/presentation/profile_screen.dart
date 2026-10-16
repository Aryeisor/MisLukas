import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/seed/demo_seed.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/dev/demo_data_actions.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/auth_messages.dart';
import 'profile_view_model.dart';

/// Perfil provisional (pantalla 10). El perfil completo de docs/05 §5.2 llega
/// en una próxima versión.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileViewModelProvider);
    final textTheme = Theme.of(context).textTheme;

    ref.listen(profileViewModelProvider.select((s) => s.signOutFailure), (
      _,
      failure,
    ) {
      if (failure != null) AppSnackbar.error(context, authMessageFor(failure));
    });

    Future<void> confirmSignOut() async {
      final confirmed = await showAppConfirmDialog(
        context,
        title: '¿Cerrar sesión?',
        message:
            'Para volver a entrar necesitarás tu correo y tu contraseña.',
        confirmLabel: 'Cerrar sesión',
      );
      if (confirmed) {
        await ref.read(profileViewModelProvider.notifier).signOut();
      }
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.screenPadding,
            AppSpacing.screenPadding,
            AppSpacing.xl,
          ),
          children: [
            Semantics(
              header: true,
              child: Text('Perfil', style: textTheme.headlineSmall),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppCard(
              child: Column(
                children: [
                  AppAvatar(initials: state.initials),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    state.fullName,
                    style: textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs / 2),
                  Text(
                    state.email,
                    style: textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const AppBanner(
              variant: AppBannerVariant.info,
              title: 'Perfil completo en una próxima versión',
            ),
            const SizedBox(height: AppSpacing.xl),
            AppSecondaryButton(
              label: 'Cerrar sesión',
              icon: Icons.logout,
              onPressed: state.isSigningOut ? null : confirmSignOut,
            ),
            // Solo en modo desarrollo; en publicación no ocupa espacio.
            if (ref.watch(demoToolsEnabledProvider)) ...[
              const SizedBox(height: AppSpacing.xl),
              const DemoDataActions(),
            ],
          ],
        ),
      ),
    );
  }
}
