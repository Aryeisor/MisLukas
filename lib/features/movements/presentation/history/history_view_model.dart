import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/category_mapping.dart';
import '../../../../core/theme/category_style.dart';
import '../../data/movements_providers.dart';
import '../../domain/entities/movement.dart';
import '../../domain/entities/movement_filter.dart';
import '../../domain/usecases/watch_movement_history.dart';

/// Opciones del selector Todos | Gastos | Ingresos, en orden.
enum HistoryTypeFilter {
  all('Todos', null),
  expenses('Gastos', MovementType.expense),
  income('Ingresos', MovementType.income);

  const HistoryTypeFilter(this.label, this.type);

  final String label;
  final MovementType? type;
}

/// Estado inmutable del historial: el filtro, cuántos meses se cargan y los
/// meses cargados.
class HistoryState {
  const HistoryState({
    this.type = HistoryTypeFilter.all,
    this.category,
    this.monthCount = historyMonthsPerPage,
    this.page = const AsyncLoading(),
    this.isLoadingMore = false,
  });

  final HistoryTypeFilter type;

  /// Categoría de gasto elegida; null para todas. Con Ingresos siempre null.
  final CategoryKind? category;
  final int monthCount;

  /// Al pedir más meses se conserva la página anterior hasta que llega la
  /// nueva.
  final AsyncValue<HistoryPage> page;
  final bool isLoadingMore;

  MovementFilter get filter =>
      MovementFilter(type: type.type, categoryId: category?.categoryId);

  /// Las categorías se ofrecen con Todos y con Gastos.
  bool get showsCategories => type != HistoryTypeFilter.income;

  HistoryState copyWith({
    AsyncValue<HistoryPage>? page,
    int? monthCount,
    bool? isLoadingMore,
  }) {
    return HistoryState(
      type: type,
      category: category,
      monthCount: monthCount ?? this.monthCount,
      page: page ?? this.page,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

final historyViewModelProvider =
    NotifierProvider.autoDispose<HistoryViewModel, HistoryState>(
      HistoryViewModel.new,
    );

/// ViewModel del historial (RF-22). Escucha el caso de uso con el filtro y la
/// cantidad de meses actuales; al cambiarlos, vuelve a escuchar.
class HistoryViewModel extends Notifier<HistoryState> {
  StreamSubscription<HistoryPage>? _subscription;

  @override
  HistoryState build() {
    // Se reconstruye con la base o el reloj: empieza de nuevo.
    ref.watch(watchMovementHistoryProvider);
    ref.onDispose(() => _subscription?.cancel());
    const initial = HistoryState();
    _listen(initial);
    return initial;
  }

  void _listen(HistoryState query) {
    _subscription?.cancel();
    _subscription = ref
        .read(watchMovementHistoryProvider)
        .call(filter: query.filter, monthCount: query.monthCount)
        .listen(
          (page) {
            state = state.copyWith(page: AsyncData(page), isLoadingMore: false);
          },
          onError: (Object error, StackTrace stackTrace) {
            // Sin log: puede incluir datos del usuario (docs/08 §8.8.5).
            state = state.copyWith(
              page: AsyncError(error, stackTrace),
              isLoadingMore: false,
            );
          },
        );
  }

  /// Cambia Todos | Gastos | Ingresos. Con Ingresos se quita la categoría.
  void selectType(HistoryTypeFilter type) {
    if (type == state.type) return;
    _restart(
      HistoryState(
        type: type,
        category: type == HistoryTypeFilter.income ? null : state.category,
      ),
    );
  }

  /// Elige una categoría de gasto, o todas con null.
  void selectCategory(CategoryKind? category) {
    if (category == state.category || !state.showsCategories) return;
    if (category != null &&
        category.defaultCategory.type != MovementType.expense) {
      return;
    }
    _restart(HistoryState(type: state.type, category: category));
  }

  void _restart(HistoryState next) {
    state = next;
    _listen(next);
  }

  /// Carga los meses siguientes, si hay.
  void loadMore() {
    final page = state.page.value;
    if (state.isLoadingMore || page == null || !page.hasMore) return;
    state = state.copyWith(
      monthCount: state.monthCount + historyMonthsPerPage,
      isLoadingMore: true,
    );
    _listen(state);
  }
}
