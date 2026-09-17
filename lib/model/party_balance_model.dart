import 'package:freezed_annotation/freezed_annotation.dart';

import 'payment_model.dart';

part 'party_balance_model.freezed.dart';

/// Derived balance for one client (receivable) or one supplier (payable).
@freezed
class PartyBalanceModel with _$PartyBalanceModel {
  const PartyBalanceModel._();

  const factory PartyBalanceModel({
    required int partyId,
    @Default('') String partyName,
    /// Client: total billed net of refunds. Supplier: total cost net of refunds.
    @Default(0) double totalOwed,
    /// Client: collected. Supplier: paid out.
    @Default(0) double totalSettled,
    @Default(0) int transactionCount,
  }) = _PartyBalanceModel;

  double get outstanding => totalOwed - totalSettled;

  PaymentStatus get status {
    if (totalOwed <= 0.005) return PaymentStatus.paid;
    if (totalSettled <= 0.005) return PaymentStatus.unpaid;
    if (totalSettled >= totalOwed - 0.005) return PaymentStatus.paid;
    return PaymentStatus.partial;
  }
}
