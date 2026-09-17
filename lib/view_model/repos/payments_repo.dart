import '../../model/payment_model.dart';

abstract class PaymentsRepo {
  Future<List<PaymentModel>> getForTransaction(int transactionId);

  Future<int> addPayment({
    required int transactionId,
    required PaymentParty party,
    required PaymentMethod method,
    required double amount,
    int? supplierId,
    DateTime? dateTime,
    String? notes,
  });

  Future<void> updatePayment(PaymentModel payment);
  Future<void> deletePayment(int id);

  /// Undo/refund: marks the payment voided rather than deleting it, so it
  /// stays visible in the payment history but no longer counts toward any
  /// paid/owed balance. Throws if already voided.
  Future<void> voidPayment(int id);

  Future<double> clientPaidOn(int transactionId);
  Future<double> supplierPaidOn(int transactionId, int supplierId);

  /// Every supplier payment in a date range — read-only cash-out visibility
  /// for the Expenses tab. Never feeds net profit, which stays COGS-based.
  Future<List<PaymentModel>> getSupplierPayments({DateTime? from, DateTime? to});

  /// Marks one rental day as paid: creates exactly one payment row carrying
  /// [transactionItemId] and [rentalDayDate]. Always a client-side payment —
  /// rental days are billed to the client.
  Future<int> markRentalDayPaid({
    required int transactionId,
    required int transactionItemId,
    required DateTime rentalDayDate,
    required double amount,
    required PaymentMethod method,
    String? notes,
  });

  /// Distinct rental days already paid on one line.
  Future<Set<DateTime>> getPaidRentalDays(int transactionItemId);
}
