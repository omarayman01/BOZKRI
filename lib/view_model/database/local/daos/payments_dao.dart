import 'package:drift/drift.dart';

import '../../../../model/payment_model.dart';
import '../../../errors/db_failure.dart';
import '../../../errors/failure.dart';
import '../app_database.dart';
import '../mappers.dart';
import '../tables.dart';

part 'payments_dao.g.dart';

@DriftAccessor(tables: <Type>[Payments, Transactions, Suppliers, Clients])
class PaymentsDao extends DatabaseAccessor<AppDatabase>
    with _$PaymentsDaoMixin {
  PaymentsDao(super.db);

  Future<List<PaymentModel>> getForTransaction(int transactionId) async {
    final List<QueryRow> rows = await customSelect(
      '''
      SELECT p.*, s.name AS supplier_name, c.name AS client_name
      FROM payments p
      LEFT JOIN suppliers s ON s.id = p.supplier_id
      JOIN transactions t ON t.id = p.transaction_id
      JOIN clients c ON c.id = t.client_id
      WHERE p.transaction_id = ?
      ORDER BY p.date_time DESC
      ''',
      variables: <Variable<Object>>[Variable<int>(transactionId)],
      readsFrom: <ResultSetImplementation<HasResultSet, Object>>{
        payments,
        suppliers,
        transactions,
        clients,
      },
    ).get();

    return rows
        .map((QueryRow r) => payments.map(r.data, tablePrefix: null).toModel(
              supplierName: r.read<String?>('supplier_name'),
              clientName: r.read<String?>('client_name'),
            ))
        .toList();
  }

  /// Supplier payments must carry [supplierId] so multi-supplier deals
  /// attribute the money to the right payable.
  Future<int> addPayment({
    required int transactionId,
    required PaymentParty party,
    required PaymentMethod method,
    required double amount,
    int? supplierId,
    DateTime? dateTime,
    String? notes,
    int? transactionItemId,
    DateTime? rentalDayDate,
  }) async {
    if (amount <= 0) {
      throw const ConstraintFailure('Payment amount must be greater than zero.');
    }
    if (party == PaymentParty.supplier && supplierId == null) {
      throw const ConstraintFailure(
          'A supplier payment must be attributed to a supplier.');
    }

    return into(payments).insert(
      PaymentsCompanion.insert(
        transactionId: transactionId,
        party: party.name,
        supplierId: Value<int?>(party == PaymentParty.supplier ? supplierId : null),
        method: method.name,
        amount: amount,
        occurredAt: dateTime ?? DateTime.now(),
        notes: Value<String?>(notes),
        transactionItemId: Value<int?>(transactionItemId),
        rentalDayDate: Value<DateTime?>(rentalDayDate),
      ),
    );
  }

  /// Undo/refund: marks the payment voided rather than deleting it, so it
  /// stays visible in the payment history but is excluded from every
  /// paid/owed sum below. Throws if already voided.
  Future<void> voidPayment(int id) async {
    final PaymentRow? row = await (select(payments)
          ..where(($PaymentsTable t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) {
      throw const NotFoundFailure('This payment no longer exists.');
    }
    if (row.voided) {
      throw const ConstraintFailure('This payment was already voided.');
    }
    await (update(payments)..where(($PaymentsTable t) => t.id.equals(id))).write(
      PaymentsCompanion(
        voided: const Value<bool>(true),
        updatedAt: Value<DateTime>(DateTime.now()),
      ),
    );
  }

  /// Rental days already paid on one line, one row per day — used to render
  /// the per-day grid without re-deriving it from the full payments list.
  /// A voided payment frees its day back up as unpaid.
  Future<Set<DateTime>> getPaidRentalDays(int transactionItemId) async {
    final List<QueryRow> rows = await customSelect(
      'SELECT rental_day_date FROM payments '
      'WHERE transaction_item_id = ? AND rental_day_date IS NOT NULL '
      'AND voided = 0',
      variables: <Variable<Object>>[Variable<int>(transactionItemId)],
      readsFrom: <ResultSetImplementation<HasResultSet, Object>>{payments},
    ).get();
    return rows.map((QueryRow r) => r.read<DateTime>('rental_day_date')).toSet();
  }

  Future<int> updatePayment(PaymentModel payment) {
    return (update(payments)
          ..where(($PaymentsTable t) => t.id.equals(payment.id)))
        .write(
      PaymentsCompanion(
        party: Value<String>(payment.party.name),
        supplierId: Value<int?>(payment.supplierId),
        method: Value<String>(payment.method.name),
        amount: Value<double>(payment.amount),
        occurredAt: Value<DateTime>(payment.dateTime),
        notes: Value<String?>(payment.notes),
        updatedAt: Value<DateTime>(DateTime.now()),
      ),
    );
  }

  Future<int> deletePayment(int id) =>
      (delete(payments)..where(($PaymentsTable t) => t.id.equals(id))).go();

  /// Every supplier payment in a date range, for the Expenses tab's
  /// read-only cash-out visibility section. Never used to derive net
  /// profit — that stays COGS-based off `transactions.totalCost`.
  Future<List<PaymentModel>> getSupplierPayments({
    DateTime? from,
    DateTime? to,
  }) async {
    final StringBuffer where = StringBuffer();
    final List<Variable<Object>> vars = <Variable<Object>>[];
    if (from != null) {
      where.write(' AND p.date_time >= ?');
      vars.add(Variable<DateTime>(from));
    }
    if (to != null) {
      where.write(' AND p.date_time <= ?');
      vars.add(Variable<DateTime>(to));
    }

    final List<QueryRow> rows = await customSelect(
      '''
      SELECT p.*, s.name AS supplier_name, c.name AS client_name
      FROM payments p
      LEFT JOIN suppliers s ON s.id = p.supplier_id
      JOIN transactions t ON t.id = p.transaction_id
      JOIN clients c ON c.id = t.client_id
      WHERE p.party = 'supplier' AND p.voided = 0${where.toString()}
      ORDER BY p.date_time DESC
      ''',
      variables: vars,
      readsFrom: <ResultSetImplementation<HasResultSet, Object>>{
        payments,
        suppliers,
        transactions,
        clients,
      },
    ).get();

    return rows
        .map((QueryRow r) => payments.map(r.data, tablePrefix: null).toModel(
              supplierName: r.read<String?>('supplier_name'),
              clientName: r.read<String?>('client_name'),
            ))
        .toList();
  }

  /// Total paid by the client on a deal, excluding voided payments.
  Future<double> clientPaidOn(int transactionId) =>
      _sum("transaction_id = ? AND party = 'client' AND voided = 0",
          <Variable<Object>>[Variable<int>(transactionId)]);

  /// Total paid to one supplier on a deal — the per-supplier-per-transaction
  /// settlement used to derive that supplier's status. Excludes voided
  /// payments.
  Future<double> supplierPaidOn(int transactionId, int supplierId) => _sum(
        "transaction_id = ? AND party = 'supplier' AND supplier_id = ? AND voided = 0",
        <Variable<Object>>[
          Variable<int>(transactionId),
          Variable<int>(supplierId),
        ],
      );

  Future<double> _sum(String where, List<Variable<Object>> vars) async {
    final QueryRow row = await customSelect(
      'SELECT COALESCE(SUM(amount), 0) AS s FROM payments WHERE $where',
      variables: vars,
      readsFrom: <ResultSetImplementation<HasResultSet, Object>>{payments},
    ).getSingle();
    return row.read<double>('s');
  }
}
