import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../sync/sync_controller.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_offline_indicator.dart';

/// Contenedor de las cuatro pestañas principales con la barra inferior fija.
/// Arriba, el aviso discreto de "Sin conexión" (docs/05 §5.3).
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(
      syncControllerProvider.select((s) => s.isOffline),
    );

    return Scaffold(
      body: Column(
        children: [
          if (offline)
            const SafeArea(bottom: false, child: AppOfflineIndicator()),
          Expanded(
            // Con el aviso arriba, las pestañas no repiten el margen superior.
            child: MediaQuery.removePadding(
              context: context,
              removeTop: offline,
              child: navigationShell,
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: navigationShell.currentIndex,
        // Tocar la pestaña activa la devuelve a su ruta inicial.
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
