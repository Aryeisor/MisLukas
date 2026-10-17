import 'dart:async';

// Utilidades de streams. Dart puro.

/// Emite el último par de valores cada vez que cualquiera de los dos cambia.
Stream<(A, B)> combineLatest<A, B>(Stream<A> first, Stream<B> second) {
  late StreamController<(A, B)> controller;
  StreamSubscription<A>? firstSub;
  StreamSubscription<B>? secondSub;
  A? lastA;
  B? lastB;
  var hasA = false;
  var hasB = false;

  void emit() {
    if (hasA && hasB) controller.add((lastA as A, lastB as B));
  }

  controller = StreamController<(A, B)>(
    onListen: () {
      firstSub = first.listen((value) {
        lastA = value;
        hasA = true;
        emit();
      }, onError: controller.addError);
      secondSub = second.listen((value) {
        lastB = value;
        hasB = true;
        emit();
      }, onError: controller.addError);
    },
    onCancel: () async {
      await firstSub?.cancel();
      await secondSub?.cancel();
    },
  );
  return controller.stream;
}

/// Por cada valor de [source], escucha el stream que devuelve [project] y
/// emite sus valores; al llegar otro valor, deja el stream anterior.
Stream<R> switchMap<T, R>(Stream<T> source, Stream<R> Function(T) project) {
  late StreamController<R> controller;
  StreamSubscription<T>? sourceSub;
  StreamSubscription<R>? innerSub;

  controller = StreamController<R>(
    onListen: () {
      sourceSub = source.listen(
        (value) {
          innerSub?.cancel();
          innerSub = project(value)
              .listen(controller.add, onError: controller.addError);
        },
        // Si [source] termina, el último stream interno sigue emitiendo.
        onError: controller.addError,
      );
    },
    onCancel: () async {
      await sourceSub?.cancel();
      await innerSub?.cancel();
    },
  );
  return controller.stream;
}
