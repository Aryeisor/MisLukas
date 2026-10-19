import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/local_data_wiper.dart';
import '../../../core/security/device_session_store.dart';
import '../../../core/sync/sync_controller.dart';
import '../../../core/sync/sync_providers.dart';
import '../data/auth_providers.dart';
import '../domain/auth_failure.dart';
import '../domain/entities/auth_user.dart';
import '../domain/repositories/auth_repository.dart';
import 'parked_session.dart';
import 'password_recovery_flow.dart';

/// Estado de la sesión con respecto a los datos de este dispositivo.
enum AccountSessionStatus {
  /// Sin sesión, con la sesión temporal de una recuperación de contraseña o
  /// con la sesión guardada en espera del bloqueo del celular
  /// ([parkedSessionProvider]).
  signedOut,

  /// Entró un usuario distinto del dueño de la base local: hay que confirmar
  /// que se borran los datos del otro antes de abrirla.
  foreignData,

  /// Borrando los datos locales del otro usuario.
  wiping,

  /// Con sesión y la base local es de este usuario: se puede usar la app.
  ready,
}

/// Resultado de [AccountSessionController.signOut].
sealed class SignOutOutcome {
  const SignOutOutcome();
}

class SignOutDone extends SignOutOutcome {
  const SignOutDone();
}

/// Quedaron [count] registros sin enviar: hay que confirmar que se pierden.
class SignOutHasPending extends SignOutOutcome {
  const SignOutHasPending(this.count);

  final int count;
}

class SignOutFailed extends SignOutOutcome {
  const SignOutFailed(this.failure);

  final AuthFailure failure;
}

final accountSessionProvider =
    NotifierProvider<AccountSessionController, AccountSessionStatus>(
      AccountSessionController.new,
    );

/// Relaciona la sesión con la base local:
/// - La base pertenece a un usuario (su id se guarda en el almacenamiento
///   seguro). Si entra otro, se pide confirmar y se borra antes de abrirla.
/// - Si la sesión se cierra sin que el usuario lo pida (revocada en el
///   servidor), los datos se conservan cifrados para enviarlos cuando vuelva
///   a entrar (docs/06 §6.6.4).
/// - Cerrar sesión con "Ingresar con huella, rostro o PIN" activo deja la
///   sesión en espera ([parkedSessionProvider]) y conserva todo; el borrado
///   total y eliminar la cuenta borran todo lo local (docs/08 §8.8.4).
class AccountSessionController extends Notifier<AccountSessionStatus> {
  /// Tiempo máximo de un borrado de datos locales. Pase lo que pase, al
  /// terminar el estado se vuelve a calcular con la sesión actual: la app
  /// nunca queda con sesión sin poder avanzar ni ver un aviso.
  static const Duration wipeTimeout = Duration(seconds: 15);

  String? _owner;
  bool _ownerLoaded = false;
  bool _wiping = false;

  AuthRepository get _auth => ref.read(authRepositoryProvider);

  /// Dueño de la base local según este controlador (pruebas y diagnóstico).
  String? get owner => _owner;

  @override
  AccountSessionStatus build() {
    if (!_ownerLoaded) {
      _owner = ref.read(initialLocalOwnerProvider);
      _ownerLoaded = true;
    }
    ref.listen(authStateProvider, (_, next) {
      if (next.hasValue) _evaluate(next.value);
    });
    ref.listen(
      passwordRecoveryInProgressProvider,
      (_, _) => _evaluate(_auth.currentUser),
    );
    ref.listen(parkedSessionProvider, (_, _) => _evaluate(_auth.currentUser));
    return _statusFor(_auth.currentUser);
  }

  /// Durante un borrado no se abre una sesión nueva; al terminar se recalcula
  /// con la sesión de ese momento ([_refresh]), así ningún cambio se pierde.
  /// Un cierre de sesión, en cambio, se aplica siempre de inmediato.
  void _evaluate(AuthUser? user) {
    if (_wiping && user != null) return;
    state = _statusFor(user);
  }

  void _refresh() {
    if (ref.mounted) state = _statusFor(_auth.currentUser);
  }

  AccountSessionStatus _statusFor(AuthUser? user) {
    // La sesión temporal de la recuperación no abre los datos.
    if (user == null || ref.read(passwordRecoveryInProgressProvider)) {
      return AccountSessionStatus.signedOut;
    }
    // La sesión guardada de este usuario espera el bloqueo del celular.
    if (ref.read(parkedSessionProvider) == user.id) {
      return AccountSessionStatus.signedOut;
    }
    final owner = _owner;
    if (owner == null) {
      // Base sin dueño (nueva, borrada o de antes de la Fase 5C): pasa a este
      // usuario.
      _claim(user.id);
      return AccountSessionStatus.ready;
    }
    return owner == user.id
        ? AccountSessionStatus.ready
        : AccountSessionStatus.foreignData;
  }

  void _claim(String userId) {
    _owner = userId;
    unawaited(
      ref
          .read(deviceSessionStoreProvider)
          .writeOwner(userId)
          .catchError((Object _) {}),
    );
  }

  /// Borra lo local con tiempo máximo. Devuelve true si se borraron la clave y
  /// el dueño (lo que decide de quién son los datos).
  Future<bool> _wipe() async {
    _wiping = true;
    try {
      await ref.read(localDataWiperProvider).wipe().timeout(wipeTimeout);
      return true;
    } catch (_) {
      return false;
    } finally {
      _wiping = false;
    }
  }

  /// El usuario aceptó borrar los datos del otro usuario de este dispositivo.
  Future<void> confirmForeignWipe() async {
    if (state != AccountSessionStatus.foreignData) return;
    state = AccountSessionStatus.wiping;
    if (await _wipe()) {
      _owner = null;
      _refresh();
      return;
    }
    // Sin borrar no se abren los datos ajenos: se cierra la sesión y se avisa.
    if (!ref.mounted) return;
    ref
        .read(accountNoticeProvider.notifier)
        .show(AccountNotice.foreignWipeFailed);
    await rejectForeignData();
  }

  /// El usuario no quiso borrar los datos del otro: se cierra su sesión.
  Future<void> rejectForeignData() async {
    try {
      await _auth.signOut();
    } on AuthFailureException {
      // signOut solo falla por causas distintas a la red; la sesión local ya
      // se borró.
    }
    _refresh();
  }

  /// Borra todo lo local después de un cierre de sesión voluntario o de
  /// eliminar la cuenta: la base queda sin dueño y la próxima cuenta entra
  /// sin aviso. Solo si no se pudo borrar la clave se conserva el dueño:
  /// entonces los datos siguen legibles y la próxima cuenta verá el aviso.
  Future<void> wipeAfterSignOut() async {
    // La sesión ya se cerró: se sale de inmediato, sin esperar el borrado.
    _refresh();
    if (await _wipe()) _owner = null;
    _refresh();
  }
}

/// Avisos de una sola vez sobre la sesión, para mostrar al usuario.
enum AccountNotice {
  /// No se pudieron borrar los datos de la otra cuenta: se cerró la sesión.
  foreignWipeFailed(
    'No pudimos borrar los datos de la otra cuenta de este celular. '
    'Inicia sesión de nuevo.',
  ),

  /// No se pudo mostrar el aviso de datos de otra cuenta: se cerró la sesión.
  sessionClosed(
    'No pudimos abrir tus datos en este celular. Inicia sesión de nuevo.',
  );

  const AccountNotice(this.message);

  final String message;
}

final accountNoticeProvider =
    NotifierProvider<AccountNoticeController, AccountNotice?>(
      AccountNoticeController.new,
    );

class AccountNoticeController extends Notifier<AccountNotice?> {
  @override
  AccountNotice? build() => null;

  void show(AccountNotice notice) => state = notice;

  void clear() => state = null;
}

final accountActionsProvider = Provider<AccountActions>(AccountActions.new);

/// Cierre de sesión y fin de la eliminación de la cuenta (docs/08 §8.8.4):
/// - [park]: con "Ingresar con huella, rostro o PIN" activo, vuelve al login
///   sin revocar la sesión ni borrar nada.
/// - [signOut]: borrado total; cierra la sesión y borra todo lo local.
/// Separado de [AccountSessionController] porque la sincronización depende
/// de ese estado.
class AccountActions {
  AccountActions(this._ref);

  final Ref _ref;

  /// Vuelve al login dejando la sesión en espera: no la revoca en Supabase ni
  /// borra la base, sus claves ni los recibos, así que los cambios sin
  /// sincronizar se envían al volver a entrar. Solo se reutiliza después del
  /// diálogo del sistema o de la contraseña.
  Future<SignOutOutcome> park() async {
    final user = _ref.read(authRepositoryProvider).currentUser;
    if (user == null ||
        _ref.read(accountSessionProvider) != AccountSessionStatus.ready) {
      return const SignOutFailed(AuthFailure.unknown);
    }
    // Sin la marca guardada no se sigue: la sesión y la sincronización quedan
    // como estaban.
    if (!await _ref.read(parkedSessionProvider.notifier).park(user.id)) {
      return const SignOutFailed(AuthFailure.unknown);
    }
    // Termina lo que estuviera en curso. El servicio detenido no se reutiliza:
    // al volver a entrar, la sincronización empieza con uno nuevo.
    await _ref.read(syncControllerProvider.notifier).shutdown();
    _ref.invalidate(syncServiceProvider);
    return const SignOutDone();
  }

  /// Borrado total: cierra la sesión y borra todo lo local. Antes intenta enviar los
  /// cambios pendientes; si quedan y no es [force], no cierra y devuelve
  /// [SignOutHasPending] para que el usuario confirme que se pierden.
  Future<SignOutOutcome> signOut({bool force = false}) async {
    final sync = _ref.read(syncControllerProvider.notifier);
    if (!force) {
      final pending = await sync.pushBeforeSignOut();
      if (pending > 0) return SignOutHasPending(pending);
    }
    await sync.shutdown();
    try {
      await _ref.read(authRepositoryProvider).signOut();
    } on AuthFailureException catch (error) {
      // La sesión sigue: la sincronización vuelve a empezar.
      _ref.invalidate(syncServiceProvider);
      return SignOutFailed(error.failure);
    }
    await _ref.read(accountSessionProvider.notifier).wipeAfterSignOut();
    return const SignOutDone();
  }

  /// Después de eliminar la cuenta en el servidor: cierra la sesión local y
  /// borra todo lo local.
  Future<void> completeAccountDeletion() async {
    await _ref.read(syncControllerProvider.notifier).shutdown();
    try {
      await _ref.read(authRepositoryProvider).signOut();
    } on AuthFailureException {
      // El usuario ya no existe en el servidor; la sesión local se borró.
    }
    await _ref.read(accountSessionProvider.notifier).wipeAfterSignOut();
  }
}
