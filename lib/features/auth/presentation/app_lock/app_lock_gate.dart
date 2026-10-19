import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../widgets/app_logo.dart';
import 'app_lock_controller.dart';
import 'unlock_screen.dart';

/// Cubre toda la app mientras está bloqueada (docs/08 §8.8.2). Se monta una
/// sola vez, por fuera de todo lo demás en el builder de MaterialApp.router:
/// tapa las pantallas, los diálogos y lo que abran la bienvenida, el aviso de
/// otra cuenta o una notificación.
///
/// El contenido queda montado pero fuera de escena (Offstage): no se pinta, no
/// recibe toques, no llega a los lectores de pantalla y conserva su estado, así
/// que un formulario abierto sigue igual al desbloquear.
///
/// También pone una capa sin datos cuando la app deja de estar activa, para
/// que la vista de recientes no muestre información (docs/08 §8.8.3). No usa
/// FLAG_SECURE: las capturas de pantalla siguen permitidas.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> {
  late final AppLifecycleListener _lifecycle;
  bool _obscured = false;

  AppLockController get _controller => ref.read(appLockProvider.notifier);

  @override
  void initState() {
    super.initState();
    final current = WidgetsBinding.instance.lifecycleState;
    _obscured = current != null && current != AppLifecycleState.resumed;
    _lifecycle = AppLifecycleListener(
      onHide: () => _controller.onHide(),
      onResume: () => _controller.onResume(),
      onStateChange: (state) {
        final obscured = state != AppLifecycleState.resumed;
        if (obscured != _obscured && mounted) {
          setState(() => _obscured = obscured);
        }
      },
    );
    // Arranque en frío bloqueado: se revisa el bloqueo del celular y se
    // muestra el diálogo del sistema cuando ya hay pantalla.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.engage();
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = ref.watch(
      appLockProvider.select((state) => state.contentVisible),
    );
    ref.listen(appLockProvider.select((state) => state.contentVisible), (
      _,
      visible,
    ) {
      // El teclado no queda abierto sobre un campo que ya no se ve.
      if (!visible) FocusManager.instance.primaryFocus?.unfocus();
    });

    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: !visible,
          child: ExcludeFocus(
            excluding: !visible,
            child: TickerMode(enabled: visible, child: widget.child),
          ),
        ),
        if (!visible) const _UnlockLayer(),
        if (_obscured) const PrivacyCover(),
      ],
    );
  }
}

/// La pantalla de desbloqueo con su propio navegador: el de la app está fuera
/// de escena y los diálogos (cerrar sesión) necesitan uno.
class _UnlockLayer extends StatelessWidget {
  const _UnlockLayer();

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (_) =>
          MaterialPageRoute<void>(builder: (_) => const UnlockScreen()),
    );
  }
}

/// Capa sin datos para la vista de recientes: logo y nombre de la app.
class PrivacyCover extends StatelessWidget {
  const PrivacyCover({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ColoredBox(
      color: AppColors.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(),
            const SizedBox(height: AppSpacing.lg),
            Text('MisLukas', style: textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}
