import '../../model/payment_model.dart';
import '../database/local/daos/payments_dao.dart';
import '../errors/error_handler.dart';
import 'payments_repo.dart';

class PaymentsRepoImpl implements PaymentsRepo {
  const PaymentsRepoImpl(this._dao);

  final PaymentsDao _dao;

  @override
  Future<List<PaymentModel>> getForTransaction(int transactionId) =>
      guard(() => _dao.getForTransaction(transactionId));

  @override
  Future<int> addPayment({
    required int transactionId,
    required PaymentParty party,
    required PaymentMethod method,
    required double amount,
    int? supplierId,
    DateTime? dateTime,
    String? notes,
  }) =>
      guard(() => _dao.addPayment(
            transactionId: transactionId,
            party: party,
            method: method,
            amount: amount,
            supplierId: supplierId,
            dateTime: dateTime,
            notes: notes?.trim(),
          ));

  @override
  Future<void> updatePayment(PaymentModel payment) =>
      guard(() => _dao.updatePayment(payment));

  @override
  Future<void> deletePayment(int id) => guard(() => _dao.deletePayment(id));

  @override
  Future<void> voidPayment(int id) => guard(() => _dao.voidPayment(id));

  @override
  Future<double> clientPaidOn(int transactionId) =>
      guard(() => _dao.clientPaidOn(transactionId));

  @override
  Future<double> supplierPaidOn(int transactionId, int supplierId) =>
      guard(() => _dao.supplierPaidOn(transactionId, supplierId));

  @override
  Future<List<PaymentModel>> getSupplierPayments({
    DateTime? from,
    DateTime? to,
  }) =>
      guard(() => _dao.getSupplierPayments(from: from, to: to));

  @override
  Future<int> markRentalDayPaid({
    required int transactionId,
    required int transactionItemId,
    required DateTime rentalDayDate,
    required double amount,
    required PaymentMethod method,
    String? notes,
  }) =>
      guard(() => _dao.addPayment(
            transactionId: transactionId,
            party: PaymentParty.client,
            method: method,
            amount: amount,
            dateTime: rentalDayDate,
            notes: notes?.trim(),
            transactionItemId: transactionItemId,
            rentalDayDate: rentalDayDate,
          ));

  @override
  Future<Set<DateTime>> getPaidRentalDays(int transactionItemId) =>
      guard(() => _dao.getPaidRentalDays(transactionItemId));
}
