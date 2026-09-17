import 'package:equatable/equatable.dart';

import '../../../model/item_model.dart';
import '../../../model/party_balance_model.dart';
import '../../../model/payment_model.dart';
import '../../../model/supplier_model.dart';
import '../../database/local/daos/suppliers_dao.dart';

enum SupplierDetailStatus { initial, loading, success, failure }

class SupplierDetailState extends Equatable {
  const SupplierDetailState({
    this.status = SupplierDetailStatus.initial,
    this.supplier,
    this.balance,
    this.items = const <ItemModel>[],
    this.transactions = const <SupplierTransactionSlice>[],
    this.payments = const <PaymentModel>[],
    this.errorMessage,
  });

  final SupplierDetailStatus status;
  final SupplierModel? supplier;
  final PartyBalanceModel? balance;

  /// Items this supplier provides — item management lives on this screen.
  final List<ItemModel> items;

  /// Deals containing a line from this supplier, with their cost slice.
  final List<SupplierTransactionSlice> transactions;
  final List<PaymentModel> payments;
  final String? errorMessage;

  bool get isLoading => status == SupplierDetailStatus.loading;
  bool get isFailure => status == SupplierDetailStatus.failure;

  SupplierDetailState copyWith({
    SupplierDetailStatus? status,
    SupplierModel? supplier,
    PartyBalanceModel? balance,
    List<ItemModel>? items,
    List<SupplierTransactionSlice>? transactions,
    List<PaymentModel>? payments,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SupplierDetailState(
      status: status ?? this.status,
      supplier: supplier ?? this.supplier,
      balance: balance ?? this.balance,
      items: items ?? this.items,
      transactions: transactions ?? this.transactions,
      payments: payments ?? this.payments,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => <Object?>[
        status,
        supplier,
        balance,
        items,
        transactions,
        payments,
        errorMessage,
      ];
}
