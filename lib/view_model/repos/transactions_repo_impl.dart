import '../../model/payment_model.dart';
import '../../model/transaction_model.dart';
import '../../model/transaction_with_items_model.dart';
import '../database/local/daos/transactions_dao.dart';
import '../errors/db_failure.dart';
import '../errors/error_handler.dart';
import 'transactions_repo.dart';

class TransactionsRepoImpl implements TransactionsRepo {
  const TransactionsRepoImpl(this._dao);

  final TransactionsDao _dao;

  @override
  Future<List<TransactionWithItemsModel>> getDeals({
    DateTime? from,
    DateTime? to,
  }) =>
      guard(() => _dao.getAllDeals(from: from, to: to));

  @override
  Future<TransactionWithItemsModel?> getDeal(int transactionId) =>
      guard(() => _dao.getDeal(transactionId));

  @override
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
    String? updatedBy,
  }) =>
      guard(() {
        _validate(lines, discount);
        _validateCommissionAndOverride(commissionAmount, paymentStatusOverride);
        return _dao.commitDeal(
          clientId: clientId,
          dealType: dealType,
          lines: lines,
          discount: discount,
          dateTime: dateTime,
          notes: notes,
          commissionName: commissionName,
          commissionAmount: commissionAmount,
          paymentStatusOverride: paymentStatusOverride?.name,
          updatedBy: updatedBy,
        );
      });

  @override
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
    String? updatedBy,
  }) =>
      guard(() {
        _validate(lines, discount);
        _validateCommissionAndOverride(commissionAmount, paymentStatusOverride);
        return _dao.editDeal(
          transactionId: transactionId,
          clientId: clientId,
          dealType: dealType,
          lines: lines,
          discount: discount,
          dateTime: dateTime,
          notes: notes,
          commissionName: commissionName,
          commissionAmount: commissionAmount,
          paymentStatusOverride: paymentStatusOverride?.name,
          updatedBy: updatedBy,
        );
      });

  void _validateCommissionAndOverride(
    double? commissionAmount,
    PaymentStatus? paymentStatusOverride,
  ) {
    if (commissionAmount != null && commissionAmount < 0) {
      throw const ConstraintFailure('Commission amount cannot be negative.');
    }
    if (paymentStatusOverride == PaymentStatus.partial) {
      throw const ConstraintFailure(
          'The payment status override can only be Paid or Unpaid.');
    }
  }

  @override
  Future<void> deleteDeal(int transactionId) =>
      guard(() => _dao.deleteDeal(transactionId));

  @override
  Future<void> closeCarLine({
    required int transactionItemId,
    required double returnKilometer,
    double? extraKmRate,
  }) =>
      guard(() => _dao.closeCarLine(
            transactionItemId: transactionItemId,
            returnKilometer: returnKilometer,
            extraKmRate: extraKmRate,
          ));

  @override
  Future<void> reopenCarLine(int transactionItemId) =>
      guard(() => _dao.reopenCarLine(transactionItemId));

  void _validate(List<DealLineInput> lines, double discount) {
    if (lines.isEmpty) {
      throw const ConstraintFailure('Add at least one line item to the deal.');
    }
    for (final DealLineInput line in lines) {
      if (line.qty <= 0) {
        throw const ConstraintFailure('Quantity must be at least 1.');
      }
      if (line.unitCost < 0 || line.unitPrice < 0) {
        throw const ConstraintFailure('Cost and price cannot be negative.');
      }
      if (line.rentStart != null &&
          line.rentEnd != null &&
          line.rentEnd!.isBefore(line.rentStart!)) {
        throw const ConstraintFailure(
            'A rent period cannot end before it starts.');
      }
    }
    final double subtotal = lines.fold<double>(
        0, (double sum, DealLineInput l) => sum + l.lineTotal);
    if (discount < 0) {
      throw const ConstraintFailure('Discount cannot be negative.');
    }
    if (discount > subtotal) {
      throw const ConstraintFailure('Discount cannot exceed the subtotal.');
    }
  }
}
