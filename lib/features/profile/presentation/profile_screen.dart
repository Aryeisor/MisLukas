import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/seed/demo_seed.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/dev/demo_data_actions.dart';
import '../../../core/widgets/widgets.dart';
import 'profile_view_model.dart';

/// Perfil provisional (pantalla 10). El perfil completo de docs/05 §5.2 llega
/// en una próxima versión.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileViewModelProvider);
    final textTheme = Theme.of(context).textTheme;

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
              onPressed: () => context.go(AppRoutes.login),
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
