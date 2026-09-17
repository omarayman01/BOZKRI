import 'package:equatable/equatable.dart';

import '../../../model/client_model.dart';
import '../../../model/party_balance_model.dart';
import '../../../model/payment_model.dart';
import '../../../model/transaction_item_model.dart';
import '../../../model/transaction_model.dart';

enum ClientDetailStatus { initial, loading, success, failure }

class ClientDetailState extends Equatable {
  const ClientDetailState({
    this.status = ClientDetailStatus.initial,
    this.client,
    this.balance,
    this.transactions = const <TransactionModel>[],
    this.payments = const <PaymentModel>[],
    this.items = const <TransactionItemModel>[],
    this.errorMessage,
  });

  final ClientDetailStatus status;
  final ClientModel? client;
  final PartyBalanceModel? balance;
  final List<TransactionModel> transactions;
  final List<PaymentModel> payments;

  /// Line items this client took, carrying the client-side expiry date.
  final List<TransactionItemModel> items;
  final String? errorMessage;

  bool get isLoading => status == ClientDetailStatus.loading;
  bool get isFailure => status == ClientDetailStatus.failure;

  ClientDetailState copyWith({
    ClientDetailStatus? status,
    ClientModel? client,
    PartyBalanceModel? balance,
    List<TransactionModel>? transactions,
    List<PaymentModel>? payments,
    List<TransactionItemModel>? items,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ClientDetailState(
      status: status ?? this.status,
      client: client ?? this.client,
      balance: balance ?? this.balance,
      transactions: transactions ?? this.transactions,
      payments: payments ?? this.payments,
      items: items ?? this.items,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => <Object?>[
        status,
        client,
        balance,
        transactions,
        payments,
        items,
        errorMessage,
      ];
}
