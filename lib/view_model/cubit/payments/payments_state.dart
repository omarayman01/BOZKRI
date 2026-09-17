import 'package:equatable/equatable.dart';

import '../../../model/payment_model.dart';

enum PaymentsStatus { initial, loading, success, failure }

class PaymentsState extends Equatable {
  const PaymentsState({
    this.status = PaymentsStatus.initial,
    this.payments = const <PaymentModel>[],
    this.transactionId,
    this.errorMessage,
    this.isSaving = false,
  });

  final PaymentsStatus status;
  final List<PaymentModel> payments;
  final int? transactionId;
  final String? errorMessage;
  final bool isSaving;

  bool get isLoading => status == PaymentsStatus.loading;
  bool get isFailure => status == PaymentsStatus.failure;
  bool get isEmpty => status == PaymentsStatus.success && payments.isEmpty;

  List<PaymentModel> get clientPayments => payments
      .where((PaymentModel p) => p.party == PaymentParty.client)
      .toList();

  List<PaymentModel> get supplierPayments => payments
      .where((PaymentModel p) => p.party == PaymentParty.supplier)
      .toList();

  List<PaymentModel> paymentsForSupplier(int supplierId) => payments
      .where((PaymentModel p) =>
          p.party == PaymentParty.supplier && p.supplierId == supplierId)
      .toList();

  PaymentsState copyWith({
    PaymentsStatus? status,
    List<PaymentModel>? payments,
    int? transactionId,
    String? errorMessage,
    bool? isSaving,
    bool clearError = false,
  }) {
    return PaymentsState(
      status: status ?? this.status,
      payments: payments ?? this.payments,
      transactionId: transactionId ?? this.transactionId,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSaving: isSaving ?? this.isSaving,
    );
  }

  @override
  List<Object?> get props =>
      <Object?>[status, payments, transactionId, errorMessage, isSaving];
}
