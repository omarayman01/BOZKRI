import '../../model/daily_point_model.dart';
import '../../model/dashboard_summary_model.dart';
import '../../model/top_party_model.dart';
import '../database/local/daos/dashboard_dao.dart';
import '../errors/error_handler.dart';
import 'dashboard_repo.dart';

class DashboardRepoImpl implements DashboardRepo {
  const DashboardRepoImpl(this._dao);

  final DashboardDao _dao;

  @override
  Future<DashboardSummaryModel> getSummary({
    required DateTime from,
    required DateTime to,
    int topCount = 5,
  }) =>
      guard(() => _dao.getSummary(from: from, to: to, topCount: topCount));

  @override
  Future<List<TopPartyModel>> getTopClients({
    required DateTime from,
    required DateTime to,
    int limit = 5,
  }) =>
      guard(() => _dao.getTopClients(from: from, to: to, limit: limit));

  @override
  Future<List<TopPartyModel>> getTopSuppliers({
    required DateTime from,
    required DateTime to,
    int limit = 5,
  }) =>
      guard(() => _dao.getTopSuppliers(from: from, to: to, limit: limit));

  @override
  Future<List<DailyPointModel>> getDailyRevenue({
    required DateTime from,
    required DateTime to,
  }) =>
      guard(() => _dao.getDailyRevenue(from: from, to: to));

  @override
  Future<double> getOutstandingReceivables() =>
      guard(_dao.getOutstandingReceivables);

  @override
  Future<double> getOutstandingPayables() => guard(_dao.getOutstandingPayables);
}
