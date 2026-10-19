// Textos del cierre de sesión, compartidos por el Perfil y la pantalla de
// desbloqueo (docs/08 §8.8.4).

/// "Tienes 3 cambios sin sincronizar…".
String unsyncedSignOutMessage(int count) => count == 1
    ? 'Tienes 1 cambio sin sincronizar. Si cierras sesión ahora, se perderá.'
    : 'Tienes $count cambios sin sincronizar. Si cierras sesión ahora, se '
          'perderán.';

/// "1 cambio" / "3 cambios".
String changesLabel(int count) => count == 1 ? '1 cambio' : '$count cambios';

/// Confirmación antes de cerrar sesión.
const String signOutConfirmTitle = '¿Cerrar sesión?';

/// Sin "Ingresar con huella, rostro o PIN": borrado total.
const String signOutConfirmMessage =
    'Para volver a entrar necesitarás tu correo y tu contraseña. Tus datos se '
    'borrarán de este celular.';

/// Con "Ingresar con huella, rostro o PIN": se conserva la sesión.
const String keepSessionSignOutMessage =
    'Podrás volver a entrar con tu huella, rostro o PIN. Tus datos se quedan '
    'guardados y cifrados en este celular.';

/// Acciones del diálogo.
const String signOutLabel = 'Cerrar sesión';
const String wipeSignOutLabel =
    'Cerrar sesión y borrar los datos de este celular';

/// Confirmación cuando quedaron cambios sin enviar.
const String unsyncedSignOutTitle = '¿Cerrar sesión sin sincronizar?';
