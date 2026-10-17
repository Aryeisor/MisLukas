import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/seed/demo_seed.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/sync/sync_controller.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/utils_providers.dart';
import '../../../core/widgets/dev/demo_data_actions.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/auth_messages.dart';
import 'profile_view_model.dart';

/// Perfil provisional (pantalla 10). El perfil completo de docs/05 §5.2 llega
/// en una próxima versión; por ahora tiene el estado de sincronización, el
/// cierre de sesión y la eliminación de la cuenta.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileViewModelProvider);
    final viewModel = ref.read(profileViewModelProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    ref.listen(profileViewModelProvider.select((s) => s.signOutFailure), (
      _,
      failure,
    ) {
      if (failure != null) AppSnackbar.error(context, authMessageFor(failure));
    });

    // Quedaron cambios sin enviar: se pierden si cierra sesión (docs/08
    // §8.8.4).
    ref.listen(profileViewModelProvider.select((s) => s.unsyncedOnSignOut), (
      _,
      count,
    ) async {
      if (count == null) return;
      final confirmed = await showAppConfirmDialog(
        context,
        title: '¿Cerrar sesión sin sincronizar?',
        message: unsyncedSignOutMessage(count),
        confirmLabel: 'Cerrar sesión',
        destructive: true,
      );
      if (confirmed) {
        await viewModel.signOut(force: true);
      } else {
        viewModel.keepSession();
      }
    });

    Future<void> confirmSignOut() async {
      final confirmed = await showAppConfirmDialog(
        context,
        title: '¿Cerrar sesión?',
        message:
            'Para volver a entrar necesitarás tu correo y tu contraseña. Tus '
            'datos se borrarán de este celular.',
        confirmLabel: 'Cerrar sesión',
      );
      if (confirmed) await viewModel.signOut();
    }

    Future<void> confirmDeleteAccount() async {
      final confirmed = await showAppConfirmDialog(
        context,
        title: '¿Eliminar tu cuenta?',
        message:
            'Se borrarán para siempre tus movimientos, presupuestos y '
            'recibos, en este celular y en la nube. Esta acción no se puede '
            'deshacer.',
        confirmLabel: 'Continuar',
        destructive: true,
      );
      if (confirmed && context.mounted) {
        await context.push(AppRoutes.deleteAccount);
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
            const SyncStatusBanner(),
            const SizedBox(height: AppSpacing.lg),
            const AppBanner(
              variant: AppBannerVariant.info,
              title: 'Perfil completo en una próxima versión',
            ),
            const SizedBox(height: AppSpacing.xl),
            // Grupo "Preferencias" de la especificación (docs/05 pantalla 10).
            const AppSectionHeader(title: 'Preferencias'),
            const SizedBox(height: AppSpacing.sm),
            AppSecondaryButton(
              label: 'Presupuestos',
              icon: Icons.account_balance_wallet_outlined,
              onPressed: () => context.push(AppRoutes.budgets),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppSecondaryButton(
              label: state.isSigningOut ? 'Cerrando sesión…' : 'Cerrar sesión',
              icon: Icons.logout,
              onPressed: state.isSigningOut ? null : confirmSignOut,
            ),
            // Solo en modo desarrollo; en publicación no ocupa espacio.
            if (ref.watch(demoToolsEnabledProvider)) ...[
              const SizedBox(height: AppSpacing.xl),
              const DemoDataActions(),
            ],
            // Al final y en rojo: fácil de encontrar, difícil de tocar por
            // error (docs/05 pantalla 10).
            const SizedBox(height: AppSpacing.xl),
            AppSecondaryButton(
              label: 'Eliminar mi cuenta',
              icon: Icons.delete_forever_outlined,
              destructive: true,
              onPressed: state.isSigningOut ? null : confirmDeleteAccount,
            ),
          ],
        ),
      ),
    );
  }
}

/// "Tienes 3 cambios sin sincronizar…".
String unsyncedSignOutMessage(int count) => count == 1
    ? 'Tienes 1 cambio sin sincronizar. Si cierras sesión ahora, se perderá.'
    : 'Tienes $count cambios sin sincronizar. Si cierras sesión ahora, se '
          'perderán.';

/// "1 cambio" / "3 cambios".
String changesLabel(int count) => count == 1 ? '1 cambio' : '$count cambios';

/// Tarjeta de estado de la sincronización (docs/05 pantalla 10, RF-47):
/// "Datos sincronizados hace 5 min" o "Sin conexión, 3 cambios pendientes".
class SyncStatusBanner extends ConsumerWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncControllerProvider);
    final pending = sync.pendingCount;

    if (sync.rejectedCount > 0) {
      final count = sync.rejectedCount;
      return AppBanner(
        variant: AppBannerVariant.error,
        title: count == 1
            ? '1 cambio no se pudo sincronizar'
            : '$count cambios no se pudieron sincronizar',
        description: 'Los volveremos a intentar más tarde.',
      );
    }
    if (sync.isOffline) {
      return AppBanner(
        icon: Icons.cloud_off_outlined,
        title: pending > 0
            ? 'Sin conexión, ${changesLabel(pending)} '
                  '${pending == 1 ? 'pendiente' : 'pendientes'}'
            : 'Sin conexión',
        description: 'Tus cambios se guardarán en el celular.',
      );
    }
    if (pending > 0) {
      return AppBanner(
        icon: Icons.cloud_upload_outlined,
        title:
            '${changesLabel(pending)} ${pending == 1 ? 'pendiente' : 'pendientes'}',
        description: sync.isSyncing
            ? 'Sincronizando…'
            : 'Se enviarán cuando haya conexión.',
      );
    }
    final last = sync.lastSyncedAt;
    if (last != null) {
      return AppBanner(
        variant: AppBannerVariant.success,
        icon: Icons.cloud_done_outlined,
        title:
            'Datos sincronizados '
            '${DateLabels.timeAgo(last, ref.watch(clockProvider).now())}',
      );
    }
    return AppBanner(
      icon: Icons.cloud_queue_outlined,
      title: sync.isSyncing
          ? 'Sincronizando…'
          : 'Tus datos están en el celular',
      description: sync.isSyncing
          ? null
          : 'Se sincronizan solos cuando hay conexión.',
    );
  }
}
