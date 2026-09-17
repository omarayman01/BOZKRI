import '../../model/payment_model.dart';
import '../../model/transaction_model.dart';
import '../../model/transaction_with_items_model.dart';
import '../database/local/daos/transactions_dao.dart';

abstract class TransactionsRepo {
  Future<List<TransactionWithItemsModel>> getDeals({
    DateTime? from,
    DateTime? to,
  });

  Future<TransactionWithItemsModel?> getDeal(int transactionId);

  /// Atomic: transaction + line snapshots + single-use consume with re-check.
  ///
  /// [commissionAmount], when set and > 0, upserts a linked expense so the
  /// commission reaches net profit through the normal expense aggregate;
  /// clearing it removes that expense. [paymentStatusOverride] only changes
  /// the DISPLAYED status — money math always uses actual payments — and
  /// must be [PaymentStatus.paid] or [PaymentStatus.unpaid] (never partial).
  Future<int> commitDeal({
    required int clientId,
    required DealType dealType,
    required List<DealLineInput> lines,
    required double discount,
    DateTime? dateTime,
    String? notes,
    String? commissionName,
    double? commissionAmount,
    PaymentStatus? paymentStatusOverride,
  });

  /// Atomic: overwrites snapshots and totals, re-checks new single-use lines.
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
    PaymentStatus? paymentStatusOverride,
  });

  /// Atomic: cascades children and releases single-use items.
  Future<void> deleteDeal(int transactionId);

  /// Closes a car line: records the return kilometer and, only when the line
  /// has an allowance set, computes and snapshots the extra-km charge using
  /// [extraKmRate] entered here at close time — one Drift transaction.
  /// Throws if the line is already closed.
  Future<void> closeCarLine({
    required int transactionItemId,
    required double returnKilometer,
    double? extraKmRate,
  });

  /// Re-opens a closed car line, clearing its settlement fields and
  /// subtracting any snapshot extraKmCharge from the deal's totals — one
  /// Drift transaction. Throws if the line is already active.
  Future<void> reopenCarLine(int transactionItemId);
}
