import 'package:drift/drift.dart';

import '../../../../model/daily_point_model.dart';
import '../../../../model/dashboard_summary_model.dart';
import '../../../../model/top_party_model.dart';
import '../app_database.dart';
import '../tables.dart';

part 'dashboard_dao.g.dart';

/// Every aggregate here is computed from the snapshot columns on
/// transaction_items / refund_items. Live item prices are never joined, so
/// editing an item's defaults cannot alter historical figures.
@DriftAccessor(tables: <Type>[
  Transactions,
  TransactionItems,
  Payments,
  Refunds,
  RefundItems,
  Expenses,
  Clients,
  Suppliers,
])
class DashboardDao extends DatabaseAccessor<AppDatabase>
    with _$DashboardDaoMixin {
  DashboardDao(super.db);

  Future<DashboardSummaryModel> getSummary({
    required DateTime from,
    required DateTime to,
    int topCount = 5,
  }) async {
    final QueryRow totals = await customSelect(
      '''
      SELECT
        (SELECT COALESCE(SUM(t.total), 0) FROM transactions t
          WHERE t.date_time BETWEEN ?1 AND ?2) AS revenue,
        (SELECT COALESCE(SUM(r.total_refunded), 0) FROM refunds r
          WHERE r.date_time BETWEEN ?1 AND ?2) AS revenue_refunded,
        (SELECT COALESCE(SUM(t.total_cost), 0) FROM transactions t
          WHERE t.date_time BETWEEN ?1 AND ?2) AS cost,
        (SELECT COALESCE(SUM(r.total_cost_refunded), 0) FROM refunds r
          WHERE r.date_time BETWEEN ?1 AND ?2) AS cost_refunded,
        (SELECT COALESCE(SUM(e.amount), 0) FROM expenses e
          WHERE e.date_time BETWEEN ?1 AND ?2) AS expenses_total,
        (SELECT COUNT(*) FROM transactions t
          WHERE t.date_time BETWEEN ?1 AND ?2) AS deal_count
      ''',
      variables: <Variable<Object>>[
        Variable<DateTime>(from),
        Variable<DateTime>(to),
      ],
      readsFrom: <ResultSetImplementation<HasResultSet, Object>>{
        transactions,
        refunds,
        expenses,
      },
    ).getSingle();

    return DashboardSummaryModel(
      netRevenue:
          totals.read<double>('revenue') - totals.read<double>('revenue_refunded'),
      netCost: totals.read<double>('cost') - totals.read<double>('cost_refunded'),
      totalExpenses: totals.read<double>('expenses_total'),
      outstandingReceivables: await getOutstandingReceivables(),
      outstandingPayables: await getOutstandingPayables(),
      dealCount: totals.read<int>('deal_count'),
      topClients: await getTopClients(from: from, to: to, limit: topCount),
      topSuppliers: await getTopSuppliers(from: from, to: to, limit: topCount),
      daily: await getDailyRevenue(from: from, to: to),
      expenses: await db.expensesDao.getInRange(from: from, to: to),
    );
  }

  /// Everything clients still owe, across all time.
  Future<double> getOutstandingReceivables() async {
    final QueryRow row = await customSelect(
      '''
      SELECT
        (SELECT COALESCE(SUM(total), 0) FROM transactions)
        - (SELECT COALESCE(SUM(total_refunded), 0) FROM refunds)
        - (SELECT COALESCE(SUM(amount), 0) FROM payments
            WHERE party = 'client' AND voided = 0)
        AS outstanding
      ''',
      readsFrom: <ResultSetImplementation<HasResultSet, Object>>{
        transactions,
        refunds,
        payments,
      },
    ).getSingle();
    return row.read<double>('outstanding');
  }

  /// Everything still owed to suppliers, across all time.
  Future<double> getOutstandingPayables() async {
    final QueryRow row = await customSelect(
      '''
      SELECT
        (SELECT COALESCE(SUM(total_cost), 0) FROM transactions)
        - (SELECT COALESCE(SUM(total_cost_refunded), 0) FROM refunds)
        - (SELECT COALESCE(SUM(amount), 0) FROM payments
            WHERE party = 'supplier' AND voided = 0)
        AS outstanding
      ''',
      readsFrom: <ResultSetImplementation<HasResultSet, Object>>{
        transactions,
        refunds,
        payments,
      },
    ).getSingle();
    return row.read<double>('outstanding');
  }

  Future<List<TopPartyModel>> getTopClients({
    required DateTime from,
    required DateTime to,
    int limit = 5,
  }) async {
    final List<QueryRow> rows = await customSelect(
      '''
      SELECT c.id AS party_id, c.name AS party_name,
             COUNT(t.id) AS deals,
             COALESCE(SUM(t.total), 0)
               - COALESCE((SELECT SUM(r.total_refunded) FROM refunds r
                            WHERE r.transaction_id IN
                              (SELECT id FROM transactions t2
                                WHERE t2.client_id = c.id
                                  AND t2.date_time BETWEEN ?1 AND ?2)), 0)
               AS net_total,
             COALESCE(SUM(t.total - t.total_cost), 0)
               - COALESCE((SELECT SUM(r.total_refunded - r.total_cost_refunded)
                             FROM refunds r
                            WHERE r.transaction_id IN
                              (SELECT id FROM transactions t3
                                WHERE t3.client_id = c.id
                                  AND t3.date_time BETWEEN ?1 AND ?2)), 0)
               AS net_profit
      FROM transactions t
      JOIN clients c ON c.id = t.client_id
      WHERE t.date_time BETWEEN ?1 AND ?2
      GROUP BY c.id, c.name
      ORDER BY net_total DESC
      LIMIT $limit
      ''',
      variables: <Variable<Object>>[
        Variable<DateTime>(from),
        Variable<DateTime>(to),
      ],
      readsFrom: <ResultSetImplementation<HasResultSet, Object>>{
        transactions,
        clients,
        refunds,
      },
    ).get();

    return rows
        .map((QueryRow r) => TopPartyModel(
              id: r.read<int>('party_id'),
              name: r.read<String>('party_name'),
              total: r.read<double>('net_total'),
              profit: r.read<double>('net_profit'),
              dealCount: r.read<int>('deals'),
            ))
        .toList();
  }

  /// Ranked by the supplier's own cost slice, net of refunded cost on their
  /// lines — not by whole-deal totalCost.
  Future<List<TopPartyModel>> getTopSuppliers({
    required DateTime from,
    required DateTime to,
    int limit = 5,
  }) async {
    final List<QueryRow> rows = await customSelect(
      '''
      SELECT s.id AS party_id, s.name AS party_name,
             COUNT(DISTINCT ti.transaction_id) AS deals,
             COALESCE(SUM(ti.unit_cost * ti.qty), 0) AS gross_cost,
             COALESCE(SUM(ti.unit_price * ti.qty), 0) AS gross_revenue,
             COALESCE((SELECT SUM(ri.unit_cost * ri.qty)
                         FROM refund_items ri
                         JOIN transaction_items ti2
                              ON ti2.id = ri.transaction_item_id
                         JOIN transactions t2 ON t2.id = ti2.transaction_id
                        WHERE ti2.supplier_id = s.id
                          AND t2.date_time BETWEEN ?1 AND ?2), 0)
               AS refunded_cost,
             COALESCE((SELECT SUM(ri.unit_price * ri.qty)
                         FROM refund_items ri
                         JOIN transaction_items ti3
                              ON ti3.id = ri.transaction_item_id
                         JOIN transactions t3 ON t3.id = ti3.transaction_id
                        WHERE ti3.supplier_id = s.id
                          AND t3.date_time BETWEEN ?1 AND ?2), 0)
               AS refunded_revenue
      FROM transaction_items ti
      JOIN transactions t ON t.id = ti.transaction_id
      JOIN suppliers s ON s.id = ti.supplier_id
      WHERE t.date_time BETWEEN ?1 AND ?2
      GROUP BY s.id, s.name
      ORDER BY gross_cost DESC
      LIMIT $limit
      ''',
      variables: <Variable<Object>>[
        Variable<DateTime>(from),
        Variable<DateTime>(to),
      ],
      readsFrom: <ResultSetImplementation<HasResultSet, Object>>{
        transactionItems,
        transactions,
        suppliers,
        refundItems,
      },
    ).get();

    return rows.map((QueryRow r) {
      final double netCost =
          r.read<double>('gross_cost') - r.read<double>('refunded_cost');
      final double netRevenue =
          r.read<double>('gross_revenue') - r.read<double>('refunded_revenue');
      return TopPartyModel(
        id: r.read<int>('party_id'),
        name: r.read<String>('party_name'),
        total: netCost,
        profit: netRevenue - netCost,
        dealCount: r.read<int>('deals'),
      );
    }).toList();
  }

  /// Daily revenue and cost, net of refunds booked on the same day.
  Future<List<DailyPointModel>> getDailyRevenue({
    required DateTime from,
    required DateTime to,
  }) async {
    final List<QueryRow> rows = await customSelect(
      '''
      SELECT day, SUM(revenue) AS revenue, SUM(cost) AS cost FROM (
        SELECT date(t.date_time, 'unixepoch', 'localtime') AS day,
               t.total AS revenue, t.total_cost AS cost
          FROM transactions t
         WHERE t.date_time BETWEEN ?1 AND ?2
        UNION ALL
        SELECT date(r.date_time, 'unixepoch', 'localtime') AS day,
               -r.total_refunded AS revenue, -r.total_cost_refunded AS cost
          FROM refunds r
         WHERE r.date_time BETWEEN ?1 AND ?2
      )
      GROUP BY day
      ORDER BY day
      ''',
      variables: <Variable<Object>>[
        Variable<DateTime>(from),
        Variable<DateTime>(to),
      ],
      readsFrom: <ResultSetImplementation<HasResultSet, Object>>{
        transactions,
        refunds,
      },
    ).get();

    return rows
        .map((QueryRow r) => DailyPointModel(
              date: DateTime.parse(r.read<String>('day')),
              revenue: r.read<double>('revenue'),
              cost: r.read<double>('cost'),
            ))
        .toList();
  }
}
