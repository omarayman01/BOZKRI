import 'package:freezed_annotation/freezed_annotation.dart';

import 'payment_model.dart';

part 'transaction_model.freezed.dart';

/// A label only. The money flow is identical for every value.
enum DealType {
  sell,
  rent,
  broker,
  service;

  static DealType fromName(String value) => DealType.values.firstWhere(
        (DealType e) => e.name == value,
        orElse: () => DealType.sell,
      );
}

enum TransactionStatus {
  active,
  partiallyRefunded,
  fullyRefunded;

  static TransactionStatus fromName(String value) =>
      TransactionStatus.values.firstWhere(
        (TransactionStatus e) => e.name == value,
        orElse: () => TransactionStatus.active,
      );
}

@freezed
class TransactionModel with _$TransactionModel {
  const TransactionModel._();

  const factory TransactionModel({
    required int id,
    required int clientId,
    required DateTime dateTime,
    required DealType dealType,
    required double subtotal,
    @Default(0) double discount,
    required double total,
    required double totalCost,
    @Default(TransactionStatus.active) TransactionStatus status,
    String? notes,
    String? clientName,
    String? clientPhone,
    String? commissionName,
    double? commissionAmount,
    /// null = use the derived status; else paid/unpaid, for DISPLAY only.
    PaymentStatus? paymentStatusOverride,
  }) = _TransactionModel;

  double get grossProfit => total - totalCost;
}
