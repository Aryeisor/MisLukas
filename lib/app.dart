import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_localization.dart';
import 'core/router/app_router.dart';
import 'core/sync/sync_controller.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/widgets/foreign_data_prompt.dart';
import 'features/budgets/presentation/budget_carry_over_controller.dart';
import 'features/movements/presentation/receipt/receipt_drafts.dart';
import 'features/onboarding/presentation/welcome_launcher.dart';

class MisLukasApp extends ConsumerWidget {
  const MisLukasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'MisLukas',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: appLocale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) => ForeignDataPrompt(
        child: WelcomeLauncher(
          child: SyncTriggers(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}

/// Mantiene viva la sincronización mientras la app está abierta y sincroniza
/// al volver a primer plano (docs/06 §6.6.2). También mantiene la continuidad
/// de presupuestos, que corre después de cada sincronización (RF-53), y la
/// limpieza de imágenes de recibos huérfanas, una vez por arranque.
class SyncTriggers extends ConsumerStatefulWidget {
  const SyncTriggers({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SyncTriggers> createState() => _SyncTriggersState();
}

class _SyncTriggersState extends ConsumerState<SyncTriggers> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(syncControllerProvider.notifier).onResume(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Solo para mantener el controlador: los cambios de estado no
    // reconstruyen la app.
    ref.listen(syncControllerProvider, (_, _) {});
    ref.listen(budgetCarryOverProvider, (_, _) {});
    ref.listen(receiptCleanupProvider, (_, _) {});
    return widget.child;
  }
}
