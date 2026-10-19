import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/auth_providers.dart';
import '../account_session_controller.dart';
import '../auth_messages.dart';
import '../sign_out_messages.dart';
import '../widgets/sign_out_dialog.dart';
import 'app_lock_controller.dart';

/// Pantalla de desbloqueo (docs/05 pantalla 4). No muestra ningún dato
/// financiero. "Ingresar con huella, rostro o PIN" vuelve a abrir el diálogo
/// del sistema; "¿No eres tú? Cerrar sesión" es la salida si el usuario no
/// puede desbloquear el celular.
class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});

  static const String unlockLabel = 'Ingresar con huella, rostro o PIN';
  static const String signOutLabel = '¿No eres tú? Cerrar sesión';
  static const String canceledMessage =
      'No se desbloqueó. Toca Ingresar con huella, rostro o PIN para '
      'intentarlo de nuevo.';
  static const String lockedOutTitle = 'Desbloqueo pausado';
  static const String lockedOutMessage =
      'Tu celular pausó el desbloqueo por varios intentos fallidos. Espera un '
      'momento e inténtalo de nuevo.';
  static const String failedMessage =
      'No pudimos usar el bloqueo de tu celular. Inténtalo de nuevo.';

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  bool _signingOut = false;

  /// Las mismas opciones del Perfil. Conservar la sesión solo se ofrece con
  /// la base de este usuario: con datos de otra cuenta, se cierra la sesión.
  Future<void> _signOut() async {
    final canKeepSession =
        ref.read(appLockProvider).canKeepSession &&
        ref.read(accountSessionProvider) == AccountSessionStatus.ready;
    final choice = await showSignOutDialog(
      context,
      canKeepSession: canKeepSession,
    );
    if (choice == SignOutChoice.cancel || !mounted) return;
    setState(() => _signingOut = true);
    final actions = ref.read(accountActionsProvider);
    if (choice == SignOutChoice.keep) {
      final outcome = await actions.park();
      if (!mounted) return;
      if (outcome case SignOutFailed(:final failure)) {
        AppSnackbar.error(context, authMessageFor(failure));
      }
      setState(() => _signingOut = false);
      return;
    }
    var outcome = await actions.signOut();
    if (outcome case SignOutHasPending(:final count) when mounted) {
      final lose = await showAppConfirmDialog(
        context,
        title: unsyncedSignOutTitle,
        message: unsyncedSignOutMessage(count),
        confirmLabel: 'Cerrar sesión',
        destructive: true,
      );
      if (lose) outcome = await actions.signOut(force: true);
    }
    if (!mounted) return;
    if (outcome case SignOutFailed(:final failure)) {
      AppSnackbar.error(context, authMessageFor(failure));
    }
    setState(() => _signingOut = false);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final lock = ref.watch(appLockProvider);
    final name = ref.watch(currentUserProvider)?.name.trim() ?? '';
    final firstName = name.isEmpty ? '' : name.split(RegExp(r'\s+')).first;
    final busy = lock.authenticating || _signingOut;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                children: [
                  const SizedBox(height: AppSpacing.xxl),
                  Center(
                    child: ExcludeSemantics(
                      child: Container(
                        width: AppSizes.iconBoxLg,
                        height: AppSizes.iconBoxLg,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_outline,
                          size: AppSizes.iconXl,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Semantics(
                    header: true,
                    child: Text(
                      firstName.isEmpty ? 'Hola' : 'Hola, $firstName',
                      textAlign: TextAlign.center,
                      style: textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    AppLockController.unlockReason,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (lock.message case final message?) ...[
                    const SizedBox(height: AppSpacing.xl),
                    _MessageBanner(message),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                0,
                AppSpacing.screenPadding,
                AppSpacing.screenPadding,
              ),
              child: Column(
                children: [
                  AppPrimaryButton(
                    label: UnlockScreen.unlockLabel,
                    icon: Icons.lock_open_outlined,
                    onPressed: busy
                        ? null
                        : ref.read(appLockProvider.notifier).unlock,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppSecondaryButton(
                    label: _signingOut
                        ? 'Cerrando sesión…'
                        : UnlockScreen.signOutLabel,
                    icon: Icons.logout,
                    onPressed: busy ? null : _signOut,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner(this.message);

  final AppLockMessage message;

  @override
  Widget build(BuildContext context) {
    return switch (message) {
      AppLockMessage.canceled => const AppBanner(
        variant: AppBannerVariant.info,
        title: UnlockScreen.canceledMessage,
      ),
      AppLockMessage.lockedOut => const AppBanner(
        variant: AppBannerVariant.warning,
        title: UnlockScreen.lockedOutTitle,
        description: UnlockScreen.lockedOutMessage,
      ),
      AppLockMessage.failed => const AppBanner(
        variant: AppBannerVariant.error,
        title: UnlockScreen.failedMessage,
      ),
    };
  }
}
