import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../model/client_model.dart';
import '../../../model/party_balance_model.dart';
import '../../../model/payment_model.dart';
import '../../../model/transaction_item_model.dart';
import '../../../model/transaction_model.dart';
import '../../errors/failure.dart';
import '../../provider/expiry_provider.dart';
import '../../repos/clients_repo.dart';
import 'client_detail_state.dart';

/// Loads every tab of one client's detail screen plus the derived balance.
class ClientDetailCubit extends Cubit<ClientDetailState> {
  ClientDetailCubit(this._repo) : super(const ClientDetailState());

  final ClientsRepo _repo;

  Future<void> load(int clientId, {ExpiryProvider? expiry}) async {
    emit(state.copyWith(status: ClientDetailStatus.loading, clearError: true));
    try {
      final ClientModel? client = await _repo.getClient(clientId);
      if (client == null) {
        emit(state.copyWith(
          status: ClientDetailStatus.failure,
          errorMessage: 'This client no longer exists.',
        ));
        return;
      }

      final List<TransactionModel> transactions =
          await _repo.getClientTransactions(clientId);
      final List<PaymentModel> payments =
          await _repo.getClientPayments(clientId);
      final List<TransactionItemModel> items =
          await _repo.getClientItems(clientId);
      final PartyBalanceModel balance = await _repo.getClientBalance(clientId);

      expiry?.setClientLines(items);

      emit(state.copyWith(
        status: ClientDetailStatus.success,
        client: client,
        transactions: transactions,
        payments: payments,
        items: items,
        balance: balance,
      ));
    } on Failure catch (failure) {
      emit(state.copyWith(
        status: ClientDetailStatus.failure,
        errorMessage: failure.message,
      ));
    }
  }

  Future<void> refresh({ExpiryProvider? expiry}) async {
    final int? id = state.client?.id;
    if (id != null) await load(id, expiry: expiry);
  }
}
