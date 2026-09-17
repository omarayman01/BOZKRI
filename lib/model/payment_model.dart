import 'package:freezed_annotation/freezed_annotation.dart';

part 'payment_model.freezed.dart';

enum PaymentParty {
  client,
  supplier;

  static PaymentParty fromName(String value) =>
      PaymentParty.values.firstWhere(
        (PaymentParty e) => e.name == value,
        orElse: () => PaymentParty.client,
      );
}

enum PaymentMethod {
  cash,
  mobileWallet,
  instapay;

  static PaymentMethod fromName(String value) =>
      PaymentMethod.values.firstWhere(
        (PaymentMethod e) => e.name == value,
        orElse: () => PaymentMethod.cash,
      );
}

/// Derived per side from payments versus owed. Never stored — except as the
/// admin's manual display-only override on [TransactionModel.paymentStatusOverride].
enum PaymentStatus {
  unpaid,
  partial,
  paid;

  static PaymentStatus fromName(String value) => PaymentStatus.values.firstWhere(
        (PaymentStatus e) => e.name == value,
        orElse: () => PaymentStatus.unpaid,
      );
}

@freezed
class PaymentModel with _$PaymentModel {
  const factory PaymentModel({
    required int id,
    required int transactionId,
    required PaymentParty party,
    int? supplierId,
    required PaymentMethod method,
    required double amount,
    required DateTime dateTime,
    String? notes,
    String? supplierName,
    String? clientName,
    int? transactionItemId,
    DateTime? rentalDayDate,
    @Default(false) bool voided,
  }) = _PaymentModel;
}
