import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../model/dashboard_summary_model.dart';
import '../../errors/failure.dart';
import '../../repos/dashboard_repo.dart';
import '../../utils/date_utils.dart';
import 'dashboard_state.dart';

/// Loads date-range analytics. Every figure is aggregated net of refunds from
/// the stored snapshots, so past numbers never shift when items are edited.
class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit(this._repo) : super(const DashboardState());

  final DashboardRepo _repo;

  Future<void> load({AppDateRange? range}) async {
    final AppDateRange effective =
        range ?? state.range ?? AppDateUtils.currentMonth();
    emit(state.copyWith(
      status: DashboardStatus.loading,
      range: effective,
      clearError: true,
    ));
    try {
      final DashboardSummaryModel summary = await _repo.getSummary(
        from: effective.start,
        to: effective.end,
      );
      emit(state.copyWith(status: DashboardStatus.success, summary: summary));
    } on Failure catch (failure) {
      emit(state.copyWith(
        status: DashboardStatus.failure,
        errorMessage: failure.message,
      ));
    }
  }

  Future<void> setRange(AppDateRange range) => load(range: range);

  Future<void> refresh() => load();
}
