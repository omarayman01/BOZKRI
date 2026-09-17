import 'package:equatable/equatable.dart';

import '../../../model/dashboard_summary_model.dart';
import '../../utils/date_utils.dart';

enum DashboardStatus { initial, loading, success, failure }

class DashboardState extends Equatable {
  const DashboardState({
    this.status = DashboardStatus.initial,
    this.summary,
    this.range,
    this.errorMessage,
  });

  final DashboardStatus status;
  final DashboardSummaryModel? summary;
  final AppDateRange? range;
  final String? errorMessage;

  bool get isLoading => status == DashboardStatus.loading;
  bool get isFailure => status == DashboardStatus.failure;
  bool get isEmpty =>
      status == DashboardStatus.success && (summary?.dealCount ?? 0) == 0;

  DashboardState copyWith({
    DashboardStatus? status,
    DashboardSummaryModel? summary,
    AppDateRange? range,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DashboardState(
      status: status ?? this.status,
      summary: summary ?? this.summary,
      range: range ?? this.range,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => <Object?>[status, summary, range, errorMessage];
}
