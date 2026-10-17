import '../../../../core/utils/clock.dart';
import '../../../../core/utils/streams.dart';
import '../entities/month_summary.dart';
import '../entities/movement.dart';
import '../entities/movement_filter.dart';
import '../repositories/movement_repository.dart';

/// Meses que el historial carga al abrir y cada vez que se pide más.
const int historyMonthsPerPage = 3;

/// Un mes del historial: sus totales y sus movimientos, del más reciente al
/// más antiguo. Inmutable.
class HistoryMonth {
  const HistoryMonth({required this.summary, required this.movements});

  final MonthSummary summary;
  final List<Movement> movements;
}

/// Meses cargados del historial y si hay meses más antiguos. Inmutable.
class HistoryPage {
  const HistoryPage({required this.months, required this.hasMore});

  static const HistoryPage empty = HistoryPage(months: [], hasMore: false);

  final List<HistoryMonth> months;
  final bool hasMore;

  bool get isEmpty => months.isEmpty;
}

/// Historial de movimientos agrupado por mes, del más reciente al más antiguo
/// (RF-22).
///
/// Para no cargar todos los movimientos, la base calcula qué meses tienen
/// movimientos y solo se leen los de los [monthCount] más recientes. Los
/// totales de cada mes se calculan con los movimientos cargados, para que
/// siempre coincidan con la lista.
class WatchMovementHistory {
  const WatchMovementHistory({required this._movements});

  final MovementRepository _movements;

  Stream<HistoryPage> call({
    MovementFilter filter = MovementFilter.all,
    int monthCount = historyMonthsPerPage,
  }) {
    return switchMap(_movements.watchMonthSummaries(filter: filter), (
      summaries,
    ) {
      if (summaries.isEmpty) return Stream.value(HistoryPage.empty);
      final visible = summaries.take(monthCount).toList();
      final hasMore = summaries.length > visible.length;
      return _movements
          .watchBetween(
            visible.last.month,
            nextMonthStart(visible.first.month),
            filter: filter,
          )
          .map((movements) => _group(movements, hasMore: hasMore));
    });
  }

  static HistoryPage _group(List<Movement> movements, {required bool hasMore}) {
    // Los movimientos llegan ordenados por fecha, del más reciente al más
    // antiguo: cada mes es un tramo seguido.
    final byMonth = <DateTime, List<Movement>>{};
    for (final movement in movements) {
      byMonth.putIfAbsent(monthStart(movement.date), () => []).add(movement);
    }
    return HistoryPage(
      months: [
        for (final MapEntry(key: month, value: items) in byMonth.entries)
          HistoryMonth(
            summary: summarizeMonth(month: month, movements: items),
            movements: List.unmodifiable(items),
          ),
      ],
      hasMore: hasMore,
    );
  }
}
