import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/widgets.dart';
import '../account_session_controller.dart';

/// Aviso global de "datos de otra cuenta". Se monta una sola vez, encima del
/// router (MaterialApp.router builder), y abre su diálogo en el navegador
/// raíz: aparece igual después del login, de verificar el registro o en
/// cualquier pantalla, y nunca dos veces.
///
/// Si entra un usuario distinto del dueño de los datos de este celular, pide
/// confirmar que se borran antes de abrir la app. No muestra nada de la otra
/// cuenta. Si el diálogo no se puede mostrar, cierra la sesión con un mensaje:
/// la app nunca queda con sesión sin poder avanzar ni ver un aviso.
///
/// También muestra los avisos de una sola vez de [accountNoticeProvider].
class ForeignDataPrompt extends ConsumerStatefulWidget {
  const ForeignDataPrompt({super.key, required this.child});

  final Widget child;

  static const String title = '¿Usar esta cuenta en este celular?';
  static const String message =
      'En este celular hay datos de otra cuenta. Si continúas, se borrarán de '
      'este dispositivo y se perderá lo que esa cuenta no haya sincronizado.';

  @override
  ConsumerState<ForeignDataPrompt> createState() => _ForeignDataPromptState();
}

class _ForeignDataPromptState extends ConsumerState<ForeignDataPrompt> {
  bool _showing = false;

  BuildContext? get _navigatorContext =>
      ref.read(rootNavigatorKeyProvider).currentContext;

  @override
  void initState() {
    super.initState();
    // La app pudo abrir ya en este estado.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          ref.read(accountSessionProvider) ==
              AccountSessionStatus.foreignData) {
        _ask();
      }
    });
  }

  Future<void> _ask() async {
    if (_showing) return;
    final controller = ref.read(accountSessionProvider.notifier);
    final navigatorContext = _navigatorContext;
    if (navigatorContext == null || !navigatorContext.mounted) {
      // Sin dónde mostrar el aviso, no se deja la sesión a medias.
      ref
          .read(accountNoticeProvider.notifier)
          .show(AccountNotice.sessionClosed);
      await controller.rejectForeignData();
      return;
    }
    _showing = true;
    final confirmed = await showAppConfirmDialog(
      navigatorContext,
      title: ForeignDataPrompt.title,
      message: ForeignDataPrompt.message,
      confirmLabel: 'Continuar',
      destructive: true,
    );
    _showing = false;
    if (!mounted) return;
    // Mientras estaba abierto pudo cambiar la sesión (por ejemplo, se cerró).
    if (ref.read(accountSessionProvider) != AccountSessionStatus.foreignData) {
      return;
    }
    if (confirmed) {
      await controller.confirmForeignWipe();
    } else {
      await controller.rejectForeignData();
    }
  }

  void _showNotice(AccountNotice notice) {
    final navigatorContext = _navigatorContext;
    if (navigatorContext != null && navigatorContext.mounted) {
      AppSnackbar.error(navigatorContext, notice.message);
    }
    ref.read(accountNoticeProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(accountSessionProvider, (previous, next) {
      if (next == AccountSessionStatus.foreignData &&
          previous != AccountSessionStatus.foreignData) {
        _ask();
      }
    });
    ref.listen(accountNoticeProvider, (_, notice) {
      if (notice != null) _showNotice(notice);
    });
    return widget.child;
  }
}
