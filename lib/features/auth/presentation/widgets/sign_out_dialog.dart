import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../sign_out_messages.dart';

/// Lo que eligió el usuario al cerrar sesión.
enum SignOutChoice {
  /// Volver al login conservando la sesión guardada y los datos.
  keep,

  /// Borrado total: cerrar la sesión y borrar los datos de este celular.
  wipe,

  /// No cerrar sesión.
  cancel,
}

/// Confirmación de "Cerrar sesión", compartida por el Perfil y la pantalla de
/// desbloqueo (docs/08 §8.8.4).
///
/// - Con [canKeepSession] (ajuste "Ingresar con huella, rostro o PIN" activo
///   y el celular con bloqueo de pantalla): "Cerrar sesión" conserva la
///   sesión y los datos, y "Cerrar sesión y borrar los datos de este celular"
///   hace el borrado total, pensado para celulares compartidos.
/// - Sin él: una sola acción, el borrado total.
Future<SignOutChoice> showSignOutDialog(
  BuildContext context, {
  required bool canKeepSession,
}) async {
  final choice = await showDialog<SignOutChoice>(
    context: context,
    builder: (dialogContext) {
      void choose(SignOutChoice choice) =>
          Navigator.of(dialogContext).pop(choice);
      final wipeStyle = TextButton.styleFrom(foregroundColor: AppColors.error);
      return AlertDialog(
        title: const Text(signOutConfirmTitle),
        content: Text(
          canKeepSession ? keepSessionSignOutMessage : signOutConfirmMessage,
        ),
        // Con tres acciones, la etiqueta larga apila los botones.
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          TextButton(
            onPressed: () => choose(SignOutChoice.cancel),
            child: const Text('Cancelar'),
          ),
          if (canKeepSession) ...[
            TextButton(
              onPressed: () => choose(SignOutChoice.wipe),
              style: wipeStyle,
              child: const Text(wipeSignOutLabel),
            ),
            TextButton(
              onPressed: () => choose(SignOutChoice.keep),
              child: const Text(signOutLabel),
            ),
          ] else
            TextButton(
              onPressed: () => choose(SignOutChoice.wipe),
              child: const Text(signOutLabel),
            ),
        ],
      );
    },
  );
  return choice ?? SignOutChoice.cancel;
}
