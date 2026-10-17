/// Estado de la bienvenida en este dispositivo (RF-51). Dart puro.
abstract interface class OnboardingRepository {
  /// La bienvenida ya se mostró y se terminó u omitió, o se decidió que no
  /// hacía falta.
  Future<bool> isWelcomeDone();

  /// Marca la bienvenida como completada. La marca se borra con los datos
  /// locales.
  Future<void> markWelcomeDone();

  /// El usuario tiene algún dato propio en este dispositivo: un movimiento o
  /// un presupuesto (aunque esté eliminado) o una categoría personalizada.
  Future<bool> hasOwnData();
}
