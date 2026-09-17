import 'package:freezed_annotation/freezed_annotation.dart';

import 'payment_model.dart';
import 'refund_item_model.dart';
import 'refund_model.dart';
import 'transaction_item_model.dart';
import 'transaction_model.dart';

part 'transaction_with_items_model.freezed.dart';

/// A deal plus every child row needed to render its detail screen and to
/// derive balances. All balances below are computed, never stored.
@freezed
class TransactionWithItemsModel with _$TransactionWithItemsModel {
  const TransactionWithItemsModel._();

  const factory TransactionWithItemsModel({
    required TransactionModel transaction,
    @Default(<TransactionItemModel>[]) List<TransactionItemModel> items,
    @Default(<PaymentModel>[]) List<PaymentModel> payments,
    @Default(<RefundModel>[]) List<RefundModel> refunds,
  }) = _TransactionWithItemsModel;

  int get id => transaction.id;

  /// The first line, by existing load order — shown as the deal's "used
  /// item" in the deals list instead of leading with the internal id.
  TransactionItemModel get primaryItem => items.first;

  /// Remaining line count beyond [primaryItem], `0` for a single-line deal.
  int get additionalItemCount => items.isEmpty ? 0 : items.length - 1;

  List<int> get supplierIds =>
      items.map((TransactionItemModel e) => e.supplierId).toSet().toList();

  List<String> get supplierNames => items
      .map((TransactionItemModel e) => e.supplierName ?? '')
      .where((String e) => e.isNotEmpty)
      .toSet()
      .toList();

  List<String> get supplierPhones => items
      .map((TransactionItemModel e) => e.supplierPhone ?? '')
      .where((String e) => e.isNotEmpty)
      .toSet()
      .toList();

  /// Whether every per-day (car) line on this deal has been closed
  /// (حالة العقد = مغلق). `false` when the deal has no per-day lines at all.
  bool get hasPerDayLines => items.any((TransactionItemModel e) => e.isPerDay);

  bool get allPerDayLinesClosed =>
      hasPerDayLines &&
      items.where((TransactionItemModel e) => e.isPerDay).every(
          (TransactionItemModel e) => e.isReturned);

  // ---- Client side ----
  double get totalRefundedToClient => refunds.fold<double>(
      0, (double sum, RefundModel r) => sum + r.totalRefunded);

  double get netClientOwed =>
      transaction.total - totalRefundedToClient;

  double get clientPaid => payments
      .where((PaymentModel p) => p.party == PaymentParty.client && !p.voided)
      .fold<double>(0, (double sum, PaymentModel p) => sum + p.amount);

  double get clientOutstanding => netClientOwed - clientPaid;

  PaymentStatus get clientStatus => _status(netClientOwed, clientPaid);

  /// The client-status chip should show: the manual override when the admin
  /// set one, otherwise the real derived status. Every money computation
  /// above always uses [clientStatus] (or the underlying payments) — never
  /// this getter.
  PaymentStatus get displayedClientStatus =>
      transaction.paymentStatusOverride ?? clientStatus;

  bool get hasClientStatusOverride => transaction.paymentStatusOverride != null;

  // ---- Supplier side ----
  double get totalCostRefunded => refunds.fold<double>(
      0, (double sum, RefundModel r) => sum + r.totalCostRefunded);

  double get netSupplierOwed => transaction.totalCost - totalCostRefunded;

  double get supplierPaid => payments
      .where((PaymentModel p) => p.party == PaymentParty.supplier && !p.voided)
      .fold<double>(0, (double sum, PaymentModel p) => sum + p.amount);

  double get supplierOutstanding => netSupplierOwed - supplierPaid;

  PaymentStatus get supplierStatus => _status(netSupplierOwed, supplierPaid);

  /// Payable owed to one specific supplier inside this deal:
  /// that supplier's line costs (net of refunded cost) minus that supplier's
  /// payments. NOT the whole transaction totalCost.
  double supplierOwed(int supplierId) {
    final double lineCost = items
        .where((TransactionItemModel e) => e.supplierId == supplierId)
        .fold<double>(0, (double sum, TransactionItemModel e) => sum + e.lineCost);

    final Set<int> supplierLineIds = items
        .where((TransactionItemModel e) => e.supplierId == supplierId)
        .map((TransactionItemModel e) => e.id)
        .toSet();

    final double refundedCost = refunds
        .expand((RefundModel r) => r.items)
        .where((RefundItemModel ri) => supplierLineIds.contains(ri.transactionItemId))
        .fold<double>(0, (double sum, RefundItemModel ri) => sum + ri.refundedCost);

    return lineCost - refundedCost;
  }

  double supplierPaidTo(int supplierId) => payments
      .where((PaymentModel p) =>
          p.party == PaymentParty.supplier &&
          p.supplierId == supplierId &&
          !p.voided)
      .fold<double>(0, (double sum, PaymentModel p) => sum + p.amount);

  double supplierOutstandingFor(int supplierId) =>
      supplierOwed(supplierId) - supplierPaidTo(supplierId);

  PaymentStatus supplierStatusFor(int supplierId) =>
      _status(supplierOwed(supplierId), supplierPaidTo(supplierId));

  // ---- Per-day rentals ----

  /// Distinct rental days already paid on one per-day line, normalized to
  /// date-only so time-of-day never causes a duplicate/missed match.
  Set<DateTime> paidRentalDaysFor(int transactionItemId) => payments
      .where((PaymentModel p) =>
          p.transactionItemId == transactionItemId && !p.voided)
      .map((PaymentModel p) => p.rentalDayDate)
      .whereType<DateTime>()
      .map((DateTime d) => DateTime(d.year, d.month, d.day))
      .toSet();

  int paidDaysFor(TransactionItemModel line) =>
      paidRentalDaysFor(line.id).length;

  int unpaidDaysFor(TransactionItemModel line) =>
      (line.days ?? 0) - paidDaysFor(line);

  /// What is still owed on this line specifically — all payments recorded
  /// against it, whether per-day or a lump sum, net of the line total.
  double lineReceivableFor(TransactionItemModel line) {
    final double paid = payments
        .where((PaymentModel p) => p.transactionItemId == line.id && !p.voided)
        .fold<double>(0, (double sum, PaymentModel p) => sum + p.amount);
    return line.finalLineTotal - paid;
  }

  // ---- Profit ----
  double get netRevenue => netClientOwed;
  double get netCost => netSupplierOwed;
  double get netProfit => netRevenue - netCost;

  static PaymentStatus _status(double owed, double paid) {
    if (owed <= 0.005) return PaymentStatus.paid;
    if (paid <= 0.005) return PaymentStatus.unpaid;
    if (paid >= owed - 0.005) return PaymentStatus.paid;
    return PaymentStatus.partial;
  }
}
