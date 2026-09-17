import '../../model/daily_point_model.dart';
import '../../model/dashboard_summary_model.dart';
import '../../model/top_party_model.dart';

abstract class DashboardRepo {
  Future<DashboardSummaryModel> getSummary({
    required DateTime from,
    required DateTime to,
    int topCount,
  });

  Future<List<TopPartyModel>> getTopClients({
    required DateTime from,
    required DateTime to,
    int limit,
  });

  Future<List<TopPartyModel>> getTopSuppliers({
    required DateTime from,
    required DateTime to,
    int limit,
  });

  Future<List<DailyPointModel>> getDailyRevenue({
    required DateTime from,
    required DateTime to,
  });

  Future<double> getOutstandingReceivables();
  Future<double> getOutstandingPayables();
}
