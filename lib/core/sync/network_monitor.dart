import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Señal rápida de red (docs/07 §7.8). Estar conectado a una red no garantiza
/// tener internet: "hay red" significa "vale la pena intentar sincronizar",
/// y solo una sincronización exitosa quita el aviso de "Sin conexión".
abstract interface class NetworkMonitor {
  /// True si el dispositivo está conectado a alguna red.
  Future<bool> hasNetwork();

  /// Cambios de red: true al conectarse a alguna, false al quedar sin ninguna.
  Stream<bool> watch();
}

/// [NetworkMonitor] con connectivity_plus.
class ConnectivityPlusNetworkMonitor implements NetworkMonitor {
  ConnectivityPlusNetworkMonitor({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static bool _anyNetwork(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);

  @override
  Future<bool> hasNetwork() async {
    try {
      return _anyNetwork(await _connectivity.checkConnectivity());
    } catch (_) {
      // Sin la señal, se asume que hay red y decide el intento.
      return true;
    }
  }

  @override
  Stream<bool> watch() =>
      _connectivity.onConnectivityChanged.map(_anyNetwork).distinct();
}

final networkMonitorProvider = Provider<NetworkMonitor>(
  (ref) => ConnectivityPlusNetworkMonitor(),
);
