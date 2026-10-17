import 'dart:async';

/// Segundos de espera entre reenvíos de un código (docs/08 §8.3 y §8.4).
const int resendCooldownSeconds = 60;

/// Cuenta regresiva de segundos para los ViewModels. Llama a [onTick] con los
/// segundos restantes al empezar y cada segundo hasta llegar a 0.
class Countdown {
  Countdown(this.onTick);

  final void Function(int remaining) onTick;
  Timer? _timer;

  void start(int seconds) {
    _timer?.cancel();
    var remaining = seconds;
    onTick(remaining);
    if (remaining <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining--;
      onTick(remaining);
      if (remaining <= 0) timer.cancel();
    });
  }

  void cancel() => _timer?.cancel();
}
