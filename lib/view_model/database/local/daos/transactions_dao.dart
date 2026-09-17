import 'package:drift/drift.dart';

import '../../../../model/payment_model.dart';
import '../../../../model/refund_item_model.dart';
import '../../../../model/refund_model.dart';
import '../../../../model/transaction_item_model.dart';
import '../../../../model/transaction_model.dart';
import '../../../../model/transaction_with_items_model.dart';
import '../../../errors/db_failure.dart';
import '../../../errors/failure.dart';
import '../../../utils/return_settlement_calculator.dart';
import '../app_database.dart';
import '../mappers.dart';
import '../tables.dart';

part 'transactions_dao.g.dart';

/// One line of a deal as entered in the builder, before it is persisted.
class DealLineInput {
  const DealLineInput({
    required this.itemId,
    required this.supplierId,
    required this.dealType,
    required this.qty,
    required this.unitCost,
    required this.unitPrice,
    this.rentStart,
    this.rentEnd,
    this.expiryDate,
    this.notes,
    this.isSingleUse = false,
    this.itemLabel,
    this.supplierName,
    this.pricePerDay,
    this.costPerDay,
    this.days,
    this.allowedKmPerDay,
    this.extraKmRate,
    this.pickupKilometer,
    this.returnKilometer,
    this.extraKmCharge,
    this.lineStatus = LineStatus.active,
    this.existingLineId,
  });

  /// The `transaction_items.id` this line was loaded from, when editing an
  /// existing deal — `null` for a line the admin adds fresh during the edit.
  /// `editDeal` uses this to update the row in place instead of deleting and
  /// re-inserting it, so any `payments` referencing it by id survive.
  final int? existingLineId;

  final int itemId;
  final int supplierId;
  final DealType dealType;
  final int qty;
  final double unitCost;
  final double unitPrice;
  final DateTime? rentStart;
  final DateTime? rentEnd;
  final DateTime? expiryDate;
  final String? notes;
  final bool isSingleUse;
  final String? itemLabel;
  final String? supplierName;

  /// Per-day pricing (cars). When set, callers are expected to also keep
  /// [qty] = [days], [unitPrice] = [pricePerDay] and [unitCost] = [costPerDay]
  /// so [lineTotal]/[lineCost] below need no separate per-day formula.
  final double? pricePerDay;
  final double? costPerDay;
  final int? days;

  /// Car kilometer parameters, entered at deal-open time, and the return
  /// settlement snapshot — carried through edits so a full-deal re-save
  /// never wipes out a settlement already recorded on this line.
  final double? allowedKmPerDay;
  final double? extraKmRate;
  final double? pickupKilometer;
  final double? returnKilometer;
  final double? extraKmCharge;
  final LineStatus lineStatus;

  bool get isPerDay => pricePerDay != null;
  bool get isReturned => lineStatus == LineStatus.returned;

  double get lineTotal => unitPrice * qty;
  double get lineCost => unitCost * qty;
  double get lineProfit => lineTotal - lineCost;

  /// Inclusive day count between [rentStart] and [rentEnd], the default for
  /// a per-day line's [days] before the admin overrides it.
  static int inclusiveDays(DateTime start, DateTime end) =>
      end.difference(start).inDays + 1;

  DealLineInput copyWith({
    int? itemId,
    int? supplierId,
    DealType? dealType,
    int? qty,
    double? unitCost,
    double? unitPrice,
    DateTime? rentStart,
    DateTime? rentEnd,
    DateTime? expiryDate,
    String? notes,
    bool? isSingleUse,
    String? itemLabel,
    String? supplierName,
    double? pricePerDay,
    double? costPerDay,
    int? days,
    double? allowedKmPerDay,
    double? extraKmRate,
    double? pickupKilometer,
    double? returnKilometer,
    double? extraKmCharge,
    LineStatus? lineStatus,
    bool clearRent = false,
    bool clearExpiry = false,
    bool clearPerDay = false,
  }) {
    return DealLineInput(
      itemId: itemId ?? this.itemId,
      supplierId: supplierId ?? this.supplierId,
      dealType: dealType ?? this.dealType,
      qty: qty ?? this.qty,
      unitCost: unitCost ?? this.unitCost,
      unitPrice: unitPrice ?? this.unitPrice,
      rentStart: clearRent ? null : (rentStart ?? this.rentStart),
      rentEnd: clearRent ? null : (rentEnd ?? this.rentEnd),
      expiryDate: clearExpiry ? null : (expiryDate ?? this.expiryDate),
      notes: notes ?? this.notes,
      isSingleUse: isSingleUse ?? this.isSingleUse,
      itemLabel: itemLabel ?? this.itemLabel,
      supplierName: supplierName ?? this.supplierName,
      pricePerDay: clearPerDay ? null : (pricePerDay ?? this.pricePerDay),
      costPerDay: clearPerDay ? null : (costPerDay ?? this.costPerDay),
      days: clearPerDay ? null : (days ?? this.days),
      allowedKmPerDay:
          clearPerDay ? null : (allowedKmPerDay ?? this.allowedKmPerDay),
      extraKmRate: clearPerDay ? null : (extraKmRate ?? this.extraKmRate),
      pickupKilometer:
          clearPerDay ? null : (pickupKilometer ?? this.pickupKilometer),
      returnKilometer: returnKilometer ?? this.returnKilometer,
      extraKmCharge: extraKmCharge ?? this.extraKmCharge,
      lineStatus: lineStatus ?? this.lineStatus,
      existingLineId: existingLineId,
    );
  }
}

@DriftAccessor(tables: <Type>[
  Transactions,
  TransactionItems,
  Payments,
  Refunds,
  RefundItems,
  Items,
  Clients,
  Suppliers,
  Expenses,
  ExpenseCategories,
])
class TransactionsDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionsDaoMixin {
  TransactionsDao(super.db);

  // -------------------------------------------------------------------------
  // Reads
  // -------------------------------------------------------------------------

  Future<List<TransactionWithItemsModel>> getAllDeals({
    DateTime? from,
    DateTime? to,
  }) async {
    final StringBuffer where = StringBuffer();
    final List<Variable<Object>> vars = <Variable<Object>>[];
    if (from != null) {
      where.write(' AND t.date_time >= ?');
      vars.add(Variable<DateTime>(from));
    }
    if (to != null) {
      where.write(' AND t.date_time <= ?');
      vars.add(Variable<DateTime>(to));
    }

    final List<QueryRow> rows = await customSelect(
      '''
      SELECT t.*, c.name AS client_name, c.phone AS client_phone
      FROM transactions t
      JOIN clients c ON c.id = t.client_id
      WHERE 1 = 1${where.toString()}
      ORDER BY t.date_time DESC
      ''',
      variables: vars,
      readsFrom: <ResultSetImplementation<HasResultSet, Object>>{
        transactions,
        clients,
      },
    ).get();

    if (rows.isEmpty) return <TransactionWithItemsModel>[];

    final List<int> ids = rows.map((QueryRow r) => r.read<int>('id')).toList();
    final Map<int, List<TransactionItemModel>> lines = await _linesFor(ids);
    final Map<int, List<PaymentModel>> pays = await _paymentsFor(ids);
    final Map<int, List<RefundModel>> refs = await _refundsFor(ids);

    return rows.map((QueryRow r) {
      final int id = r.read<int>('id');
      return TransactionWithItemsModel(
        transaction: transactions.map(r.data, tablePrefix: null).toModel(
              clientName: r.read<String>('client_name'),
              clientPhone: r.read<String?>('client_phone'),
            ),
        items: lines[id] ?? const <TransactionItemModel>[],
        payments: pays[id] ?? const <PaymentModel>[],
        refunds: refs[id] ?? const <RefundModel>[],
      );
    }).toList();
  }

  Future<TransactionWithItemsModel?> getDeal(int transactionId) async {
    final List<QueryRow> rows = await customSelect(
      '''
      SELECT t.*, c.name AS client_name, c.phone AS client_phone
      FROM transactions t
      JOIN clients c ON c.id = t.client_id
      WHERE t.id = ?
      ''',
      variables: <Variable<Object>>[Variable<int>(transactionId)],
      readsFrom: <ResultSetImplementation<HasResultSet, Object>>{
        transactions,
        clients,
      },
    ).get();

    if (rows.isEmpty) return null;

    final List<int> ids = <int>[transactionId];
    final Map<int, List<TransactionItemModel>> lines = await _linesFor(ids);
    final Map<int, List<PaymentModel>> pays = await _paymentsFor(ids);
    final Map<int, List<RefundModel>> refs = await _refundsFor(ids);

    return TransactionWithItemsModel(
      transaction: transactions.map(rows.first.data, tablePrefix: null).toModel(
            clientName: rows.first.read<String>('client_name'),
            clientPhone: rows.first.read<String?>('client_phone'),
          ),
      items: lines[transactionId] ?? const <TransactionItemModel>[],
      payments: pays[transactionId] ?? const <PaymentModel>[],
      refunds: refs[transactionId] ?? const <RefundModel>[],
    );
  }

  Future<Map<int, List<TransactionItemModel>>> _linesFor(List<int> ids) async {
    if (ids.isEmpty) return <int, List<TransactionItemModel>>{};
    final String placeholders = List<String>.filled(ids.length, '?').join(',');
    final List<QueryRow> rows = await customSelect(
      '''
      SELECT ti.*, i.label AS item_label, i.is_single_use AS single_use,
             s.name AS supplier_name, s.phone AS supplier_phone,
             COALESCE((SELECT SUM(ri.qty) FROM refund_items ri
                        WHERE ri.transaction_item_id = ti.id), 0) AS refunded_qty
      FROM transaction_items ti
      JOIN items i ON i.id = ti.item_id
      JOIN suppliers s ON s.id = ti.supplier_id
      WHERE ti.transaction_id IN ($placeholders)
      ORDER BY ti.id
      ''',
      variables: ids.map((int e) => Variable<int>(e)).toList(),
      readsFrom: <ResultSetImplementation<HasResultSet, Object>>{
        transactionItems,
        items,
        suppliers,
        refundItems,
      },
    ).get();

    final Map<int, List<TransactionItemModel>> map =
        <int, List<TransactionItemModel>>{};
    for (final QueryRow r in rows) {
      final TransactionItemModel model =
          transactionItems.map(r.data, tablePrefix: null).toModel(
                itemLabel: r.read<String>('item_label'),
                supplierName: r.read<String>('supplier_name'),
                supplierPhone: r.read<String?>('supplier_phone'),
                isSingleUse: r.read<int>('single_use') == 1,
                refundedQty: r.read<int>('refunded_qty'),
              );
      map.putIfAbsent(model.transactionId, () => <TransactionItemModel>[])
          .add(model);
    }
    return map;
  }

  Future<Map<int, List<PaymentModel>>> _paymentsFor(List<int> ids) async {
    if (ids.isEmpty) return <int, List<PaymentModel>>{};
    final String placeholders = List<String>.filled(ids.length, '?').join(',');
    final List<QueryRow> rows = await customSelect(
      '''
      SELECT p.*, s.name AS supplier_name
      FROM payments p
      LEFT JOIN suppliers s ON s.id = p.supplier_id
      WHERE p.transaction_id IN ($placeholders)
      ORDER BY p.date_time DESC
      ''',
      variables: ids.map((int e) => Variable<int>(e)).toList(),
      readsFrom: <ResultSetImplementation<HasResultSet, Object>>{
        payments,
        suppliers,
      },
    ).get();

    final Map<int, List<PaymentModel>> map = <int, List<PaymentModel>>{};
    for (final QueryRow r in rows) {
      final PaymentModel model = payments
          .map(r.data, tablePrefix: null)
          .toModel(supplierName: r.read<String?>('supplier_name'));
      map.putIfAbsent(model.transactionId, () => <PaymentModel>[]).add(model);
    }
    return map;
  }

  Future<Map<int, List<RefundModel>>> _refundsFor(List<int> ids) async {
    if (ids.isEmpty) return <int, List<RefundModel>>{};
    final String placeholders = List<String>.filled(ids.length, '?').join(',');
    final List<RefundRow> refundRows = await customSelect(
      'SELECT * FROM refunds WHERE transaction_id IN ($placeholders) '
      'ORDER BY date_time DESC',
      variables: ids.map((int e) => Variable<int>(e)).toList(),
      readsFrom: <ResultSetImplementation<HasResultSet, Object>>{refunds},
    ).map((QueryRow r) => refunds.map(r.data, tablePrefix: null)).get();

    if (refundRows.isEmpty) return <int, List<RefundModel>>{};

    final List<int> refundIds = refundRows.map((RefundRow r) => r.id).toList();
    final String riPlaceholders =
        List<String>.filled(refundIds.length, '?').join(',');
    final List<QueryRow> itemRows = await customSelect(
      '''
      SELECT ri.*, i.label AS item_label
      FROM refund_items ri
      JOIN items i ON i.id = ri.item_id
      WHERE ri.refund_id IN ($riPlaceholders)
      ''',
      variables: refundIds.map((int e) => Variable<int>(e)).toList(),
      readsFrom: <ResultSetImplementation<HasResultSet, Object>>{
        refundItems,
        items,
      },
    ).get();

    final Map<int, List<RefundItemModel>> byRefund =
        <int, List<RefundItemModel>>{};
    for (final QueryRow r in itemRows) {
      final RefundItemModel model = refundItems
          .map(r.data, tablePrefix: null)
          .toModel(itemLabel: r.read<String>('item_label'));
      byRefund.putIfAbsent(model.refundId, () => <RefundItemModel>[])
          .add(model);
    }

    final Map<int, List<RefundModel>> map = <int, List<RefundModel>>{};
    for (final RefundRow r in refundRows) {
      map.putIfAbsent(r.transactionId, () => <RefundModel>[]).add(
            r.toModel(items: byRefund[r.id] ?? const <RefundItemModel>[]),
          );
    }
    return map;
  }

  // -------------------------------------------------------------------------
  // Commit / edit / delete — each a single Drift transaction
  // -------------------------------------------------------------------------

  /// Writes the deal, its line snapshots, and consumes single-use items.
  ///
  /// Throws [ItemUnavailableFailure] (rolling everything back) if a single-use
  /// item was taken by another deal between picking it and committing.
  Future<int> commitDeal({
    required int clientId,
    required DealType dealType,
    required List<DealLineInput> lines,
    required double discount,
    DateTime? dateTime,
    String? notes,
    String? commissionName,
    double? commissionAmount,
    String? paymentStatusOverride,
  }) {
    return transaction(() async {
      if (lines.isEmpty) {
        throw const ConstraintFailure('A deal needs at least one line item.');
      }

      await _assertSingleUseAvailable(lines);

      final double subtotal = lines.fold<double>(
          0, (double sum, DealLineInput l) => sum + _lineFinalTotal(l));
      final double totalCost = lines.fold<double>(
          0, (double sum, DealLineInput l) => sum + l.lineCost);
      final double total = subtotal - discount;

      final int txId = await into(transactions).insert(
        TransactionsCompanion.insert(
          clientId: clientId,
          occurredAt: dateTime ?? DateTime.now(),
          dealType: dealType.name,
          subtotal: subtotal,
          discount: Value<double>(discount),
          total: total,
          totalCost: totalCost,
          status: TransactionStatus.active.name,
          notes: Value<String?>(notes),
          commissionName: Value<String?>(commissionName),
          commissionAmount: Value<double?>(commissionAmount),
          paymentStatusOverride: Value<String?>(paymentStatusOverride),
        ),
      );

      await _insertLines(txId, lines);
      await _consumeSingleUse(lines);
      await _syncCommissionExpense(txId, commissionName, commissionAmount);
      return txId;
    });
  }

  double _lineFinalTotal(DealLineInput l) => l.lineTotal + (l.extraKmCharge ?? 0);

  /// Mirrors the deal's commission into a linked expense so it reaches net
  /// profit through the existing expense aggregate. Clearing the commission
  /// (null or <= 0) removes the linked expense.
  Future<void> _syncCommissionExpense(
    int transactionId,
    String? commissionName,
    double? commissionAmount,
  ) async {
    final ExpenseCategoryRow? category = await (select(expenseCategories)
          ..where(($ExpenseCategoriesTable t) =>
              t.name.equals(_commissionExpenseTitle)))
        .getSingleOrNull();

    final ExpenseRow? existing = category == null
        ? null
        : await (select(expenses)
              ..where(($ExpensesTable t) =>
                  t.transactionId.equals(transactionId) &
                  t.categoryId.equals(category.id)))
            .getSingleOrNull();

    if (commissionAmount == null || commissionAmount <= 0) {
      if (existing != null) {
        await (delete(expenses)..where(($ExpensesTable t) => t.id.equals(existing.id)))
            .go();
      }
      return;
    }

    final int categoryId = category?.id ?? await into(expenseCategories)
        .insert(ExpenseCategoriesCompanion.insert(name: _commissionExpenseTitle));

    if (existing == null) {
      await into(expenses).insert(
        ExpensesCompanion.insert(
          title: _commissionExpenseTitle,
          amount: commissionAmount,
          categoryId: Value<int?>(categoryId),
          transactionId: Value<int?>(transactionId),
          occurredAt: DateTime.now(),
          note: Value<String?>(commissionName),
        ),
      );
    } else {
      await (update(expenses)..where(($ExpensesTable t) => t.id.equals(existing.id)))
          .write(ExpensesCompanion(
        amount: Value<double>(commissionAmount),
        categoryId: Value<int?>(categoryId),
        note: Value<String?>(commissionName),
      ));
    }
  }

  static const String _commissionExpenseTitle = 'عمولة';

  /// Updates the deal's line snapshots and totals in one transaction,
  /// preserving line identity wherever possible.
  ///
  /// A submitted line with a non-null [DealLineInput.existingLineId] that
  /// still exists on the deal is updated in place — the `transaction_items`
  /// row keeps its id, so any `payments` referencing it by
  /// `transaction_item_id` (in particular per-day rental-day payments) stay
  /// valid. A line whose `existingLineId` no longer appears in the submitted
  /// set is a real removal and is deleted (cascading away its own payments,
  /// correctly). A line with no `existingLineId` is inserted as new. This
  /// replaces the prior delete-all/reinsert strategy, which silently
  /// deleted every payment on every line on any edit, because the lines
  /// were always recreated with new ids.
  ///
  /// Single-use items dropped from the deal are released; newly added ones
  /// are re-checked and consumed.
  Future<void> editDeal({
    required int transactionId,
    required int clientId,
    required DealType dealType,
    required List<DealLineInput> lines,
    required double discount,
    DateTime? dateTime,
    String? notes,
    String? commissionName,
    double? commissionAmount,
    String? paymentStatusOverride,
  }) {
    return transaction(() async {
      if (lines.isEmpty) {
        throw const ConstraintFailure('A deal needs at least one line item.');
      }

      final List<TransactionItemRow> existing = await (select(transactionItems)
            ..where(($TransactionItemsTable t) =>
                t.transactionId.equals(transactionId)))
          .get();
      final Map<int, TransactionItemRow> existingById = <int, TransactionItemRow>{
        for (final TransactionItemRow r in existing) r.id: r,
      };

      final Set<int> previousItemIds =
          existing.map((TransactionItemRow e) => e.itemId).toSet();
      final Set<int> nextItemIds =
          lines.map((DealLineInput e) => e.itemId).toSet();

      // Release single-use items no longer on the deal, so the availability
      // re-check below sees the correct state.
      final Set<int> released = previousItemIds.difference(nextItemIds);
      for (final int itemId in released) {
        await _setAvailability(itemId, true);
      }

      final List<DealLineInput> toUpdate = <DealLineInput>[];
      final List<DealLineInput> toInsert = <DealLineInput>[];
      for (final DealLineInput l in lines) {
        if (l.existingLineId != null && existingById.containsKey(l.existingLineId)) {
          toUpdate.add(l);
        } else {
          toInsert.add(l);
        }
      }

      await _assertSingleUseAvailable(toInsert);
      await _assertPaidDaysWithinNewRange(toUpdate, existingById);

      // Refund rows reference transaction_items; a shrunk/replaced line set
      // could orphan them, so a re-edit clears refunds for this deal — the
      // rows this phase preserves are payments, not refunds.
      await (delete(refunds)
            ..where(($RefundsTable t) => t.transactionId.equals(transactionId)))
          .go();

      // Lines genuinely removed from the deal — cascades their own payments,
      // which is correct: the line itself is gone.
      final Set<int> submittedExistingIds = toUpdate
          .map((DealLineInput l) => l.existingLineId!)
          .toSet();
      final List<int> removedIds = existing
          .where((TransactionItemRow r) => !submittedExistingIds.contains(r.id))
          .map((TransactionItemRow r) => r.id)
          .toList();
      if (removedIds.isNotEmpty) {
        await (delete(transactionItems)
              ..where(($TransactionItemsTable t) => t.id.isIn(removedIds)))
            .go();
      }

      final double subtotal = lines.fold<double>(
          0, (double sum, DealLineInput l) => sum + _lineFinalTotal(l));
      final double totalCost = lines.fold<double>(
          0, (double sum, DealLineInput l) => sum + l.lineCost);

      await (update(transactions)
            ..where(($TransactionsTable t) => t.id.equals(transactionId)))
          .write(
        TransactionsCompanion(
          clientId: Value<int>(clientId),
          dealType: Value<String>(dealType.name),
          subtotal: Value<double>(subtotal),
          discount: Value<double>(discount),
          total: Value<double>(subtotal - discount),
          totalCost: Value<double>(totalCost),
          status: Value<String>(TransactionStatus.active.name),
          notes: Value<String?>(notes),
          commissionName: Value<String?>(commissionName),
          commissionAmount: Value<double?>(commissionAmount),
          paymentStatusOverride: Value<String?>(paymentStatusOverride),
          occurredAt: dateTime == null
              ? const Value<DateTime>.absent()
              : Value<DateTime>(dateTime),
        ),
      );

      for (final DealLineInput l in toUpdate) {
        await (update(transactionItems)
              ..where(($TransactionItemsTable t) => t.id.equals(l.existingLineId!)))
            .write(TransactionItemsCompanion(
          itemId: Value<int>(l.itemId),
          supplierId: Value<int>(l.supplierId),
          dealType: Value<String>(l.dealType.name),
          qty: Value<int>(l.qty),
          unitCost: Value<double>(l.unitCost),
          unitPrice: Value<double>(l.unitPrice),
          lineTotal: Value<double>(l.lineTotal),
          rentStart: Value<DateTime?>(l.rentStart),
          rentEnd: Value<DateTime?>(l.rentEnd),
          expiryDate: Value<DateTime?>(l.expiryDate),
          notes: Value<String?>(l.notes),
          pricePerDay: Value<double?>(l.pricePerDay),
          costPerDay: Value<double?>(l.costPerDay),
          days: Value<int?>(l.days),
          allowedKmPerDay: Value<double?>(l.allowedKmPerDay),
          extraKmRate: Value<double?>(l.extraKmRate),
          pickupKilometer: Value<double?>(l.pickupKilometer),
          returnKilometer: Value<double?>(l.returnKilometer),
          extraKmCharge: Value<double?>(l.extraKmCharge),
          lineStatus: Value<String>(l.lineStatus.name),
        ));
      }
      if (toInsert.isNotEmpty) {
        await _insertLines(transactionId, toInsert);
      }

      await _consumeSingleUse(toInsert);
      await _syncCommissionExpense(transactionId, commissionName, commissionAmount);
    });
  }

  /// Blocks shrinking a per-day line's `days` past an already-paid rental
  /// day. Runs before any write in [editDeal] commits, so a violation rolls
  /// the whole transaction back untouched.
  Future<void> _assertPaidDaysWithinNewRange(
    List<DealLineInput> toUpdate,
    Map<int, TransactionItemRow> existingById,
  ) async {
    for (final DealLineInput l in toUpdate) {
      final TransactionItemRow prev = existingById[l.existingLineId]!;
      final int? oldDays = prev.days;
      final int? newDays = l.days;
      final DateTime? rentStart = l.rentStart ?? prev.rentStart;
      if (oldDays == null || newDays == null || rentStart == null) continue;
      if (newDays >= oldDays) continue;

      final DateTime windowEnd = rentStart.add(Duration(days: newDays));
      final List<PaymentRow> paidDays = await (select(payments)
            ..where(($PaymentsTable t) =>
                t.transactionItemId.equals(l.existingLineId!) &
                t.rentalDayDate.isNotNull()))
          .get();

      final bool violatesRange = paidDays.any((PaymentRow p) {
        final DateTime day = p.rentalDayDate!;
        return day.isBefore(rentStart) || !day.isBefore(windowEnd);
      });
      if (violatesRange) {
        throw const ConstraintFailure(
          'تحذير: توجد أيام مدفوعة خارج المدة الجديدة — الغِ تحديد تلك '
          'الأيام أولاً قبل تقليل المدة.',
        );
      }
    }
  }

  /// The one line being settled, for computing the preview.
  Future<TransactionItemRow?> getLineRow(int transactionItemId) =>
      (select(transactionItems)
            ..where(($TransactionItemsTable t) => t.id.equals(transactionItemId)))
          .getSingleOrNull();

  /// Closes a car line: records the return kilometer and, only when the line
  /// has `allowedKmPerDay` set, runs the full km settlement (using
  /// [extraKmRate] entered here at close time) and folds the resulting
  /// `extraKmCharge` into the deal's `subtotal`/`total`. A line with no
  /// allowance is closed with no settlement fields touched — its
  /// `extraKmCharge` stays `NULL`. One Drift transaction; throws if the line
  /// is already closed.
  Future<void> closeCarLine({
    required int transactionItemId,
    required double returnKilometer,
    double? extraKmRate,
  }) {
    return transaction(() async {
      final TransactionItemRow? line = await getLineRow(transactionItemId);
      if (line == null) {
        throw const NotFoundFailure('This deal line no longer exists.');
      }
      if (line.lineStatus == LineStatus.returned.name) {
        throw const ConstraintFailure('This line has already been closed.');
      }

      double? extraKmCharge;
      if (line.allowedKmPerDay != null) {
        if (extraKmRate == null ||
            line.pickupKilometer == null ||
            line.days == null ||
            line.pricePerDay == null) {
          throw const ConstraintFailure(
              'This line is missing its kilometer parameters and cannot be closed.');
        }
        extraKmCharge = ReturnSettlementCalculator.compute(
          pickupKilometer: line.pickupKilometer!,
          returnKilometer: returnKilometer,
          allowedKmPerDay: line.allowedKmPerDay!,
          days: line.days!,
          extraKmRate: extraKmRate,
          pricePerDay: line.pricePerDay!,
          alreadyPaid: 0,
        ).extraKmCharge;
      }

      await (update(transactionItems)
            ..where(($TransactionItemsTable t) => t.id.equals(transactionItemId)))
          .write(TransactionItemsCompanion(
        returnKilometer: Value<double?>(returnKilometer),
        extraKmRate: line.allowedKmPerDay != null
            ? Value<double?>(extraKmRate)
            : const Value<double?>.absent(),
        extraKmCharge: Value<double?>(extraKmCharge),
        lineStatus: Value<String>(LineStatus.returned.name),
      ));

      if (extraKmCharge != null && extraKmCharge != 0) {
        final TransactionRow deal = await (select(transactions)
              ..where(($TransactionsTable t) => t.id.equals(line.transactionId)))
            .getSingle();

        await (update(transactions)
              ..where(($TransactionsTable t) => t.id.equals(line.transactionId)))
            .write(TransactionsCompanion(
          subtotal: Value<double>(deal.subtotal + extraKmCharge),
          total: Value<double>(deal.total + extraKmCharge),
        ));
      }
    });
  }

  /// Re-opens a closed car line: clears `returnKilometer`/`extraKmRate`/
  /// `extraKmCharge` back to `NULL`, sets `lineStatus = active`, and — if the
  /// line had a settlement — subtracts its `extraKmCharge` from the deal's
  /// `subtotal`/`total` so the deal's stored totals never drift from the sum
  /// of its lines. One Drift transaction; throws if the line is already
  /// active.
  Future<void> reopenCarLine(int transactionItemId) {
    return transaction(() async {
      final TransactionItemRow? line = await getLineRow(transactionItemId);
      if (line == null) {
        throw const NotFoundFailure('This deal line no longer exists.');
      }
      if (line.lineStatus == LineStatus.active.name) {
        throw const ConstraintFailure('This line is already open.');
      }

      final double previousCharge = line.extraKmCharge ?? 0;

      await (update(transactionItems)
            ..where(($TransactionItemsTable t) => t.id.equals(transactionItemId)))
          .write(const TransactionItemsCompanion(
        returnKilometer: Value<double?>(null),
        extraKmRate: Value<double?>(null),
        extraKmCharge: Value<double?>(null),
        lineStatus: Value<String>('active'),
      ));

      if (previousCharge != 0) {
        final TransactionRow deal = await (select(transactions)
              ..where(($TransactionsTable t) => t.id.equals(line.transactionId)))
            .getSingle();

        await (update(transactions)
              ..where(($TransactionsTable t) => t.id.equals(line.transactionId)))
            .write(TransactionsCompanion(
          subtotal: Value<double>(deal.subtotal - previousCharge),
          total: Value<double>(deal.total - previousCharge),
        ));
      }
    });
  }

  /// Deletes the deal and every child row, releasing single-use items.
  /// FK cascade removes transaction_items, payments, refunds and refund_items;
  /// availability is restored explicitly first.
  Future<void> deleteDeal(int transactionId) {
    return transaction(() async {
      final List<TransactionItemRow> lines = await (select(transactionItems)
            ..where(($TransactionItemsTable t) =>
                t.transactionId.equals(transactionId)))
          .get();

      for (final TransactionItemRow line in lines) {
        await _setAvailability(line.itemId, true);
      }

      await (delete(transactions)
            ..where(($TransactionsTable t) => t.id.equals(transactionId)))
          .go();
    });
  }

  // -------------------------------------------------------------------------
  // Internals
  // -------------------------------------------------------------------------

  Future<void> _insertLines(int txId, List<DealLineInput> lines) async {
    await batch((Batch b) {
      b.insertAll(
        transactionItems,
        lines
            .map((DealLineInput l) => TransactionItemsCompanion.insert(
                  transactionId: txId,
                  itemId: l.itemId,
                  supplierId: l.supplierId,
                  dealType: l.dealType.name,
                  qty: Value<int>(l.qty),
                  unitCost: l.unitCost,
                  unitPrice: l.unitPrice,
                  lineTotal: l.lineTotal,
                  rentStart: Value<DateTime?>(l.rentStart),
                  rentEnd: Value<DateTime?>(l.rentEnd),
                  expiryDate: Value<DateTime?>(l.expiryDate),
                  notes: Value<String?>(l.notes),
                  pricePerDay: Value<double?>(l.pricePerDay),
                  costPerDay: Value<double?>(l.costPerDay),
                  days: Value<int?>(l.days),
                  allowedKmPerDay: Value<double?>(l.allowedKmPerDay),
                  extraKmRate: Value<double?>(l.extraKmRate),
                  pickupKilometer: Value<double?>(l.pickupKilometer),
                  returnKilometer: Value<double?>(l.returnKilometer),
                  extraKmCharge: Value<double?>(l.extraKmCharge),
                  lineStatus: Value<String>(l.lineStatus.name),
                ))
            .toList(),
      );
    });
  }

  /// Second half of the dual enforcement: the picker filters unavailable
  /// single-use items, and this re-check runs inside the write transaction.
  Future<void> _assertSingleUseAvailable(List<DealLineInput> lines) async {
    final List<int> singleUseIds = lines
        .where((DealLineInput l) => l.isSingleUse)
        .map((DealLineInput l) => l.itemId)
        .toList();
    if (singleUseIds.isEmpty) return;

    final List<ItemRow> rows = await (select(items)
          ..where(($ItemsTable t) => t.id.isIn(singleUseIds)))
        .get();

    for (final ItemRow row in rows) {
      if (row.isSingleUse && !row.isAvailable) {
        throw ItemUnavailableFailure(
          '"${row.label}" is a single-use item and is no longer available.',
          itemId: row.id,
          itemLabel: row.label,
        );
      }
    }
  }

  Future<void> _consumeSingleUse(List<DealLineInput> lines) async {
    for (final DealLineInput line in lines.where((DealLineInput l) => l.isSingleUse)) {
      await _setAvailability(line.itemId, false);
    }
  }

  Future<void> _setAvailability(int itemId, bool available) async {
    await (update(items)
          ..where(($ItemsTable t) =>
              t.id.equals(itemId) & t.isSingleUse.equals(true)))
        .write(ItemsCompanion(isAvailable: Value<bool>(available)));
  }
}
