import 'package:freezed_annotation/freezed_annotation.dart';

import 'daily_point_model.dart';
import 'expense_model.dart';
import 'top_party_model.dart';

part 'dashboard_summary_model.freezed.dart';

/// Aggregates for a date range, all net of refunds.
@freezed
class DashboardSummaryModel with _$DashboardSummaryModel {
  const DashboardSummaryModel._();

  const factory DashboardSummaryModel({
    @Default(0) double netRevenue,
    @Default(0) double netCost,
    @Default(0) double totalExpenses,
    @Default(0) double outstandingReceivables,
    @Default(0) double outstandingPayables,
    @Default(0) int dealCount,
    @Default(<TopPartyModel>[]) List<TopPartyModel> topClients,
    @Default(<TopPartyModel>[]) List<TopPartyModel> topSuppliers,
    @Default(<DailyPointModel>[]) List<DailyPointModel> daily,
    @Default(<ExpenseModel>[]) List<ExpenseModel> expenses,
  }) = _DashboardSummaryModel;

  double get grossProfit => netRevenue - netCost;
  double get netProfit => grossProfit - totalExpenses;
}
