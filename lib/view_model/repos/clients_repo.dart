import '../../model/client_model.dart';
import '../../model/party_balance_model.dart';
import '../../model/payment_model.dart';
import '../../model/transaction_item_model.dart';
import '../../model/transaction_model.dart';

/// Contract for client data. Implementations throw [Failure] subclasses.
abstract class ClientsRepo {
  Future<List<ClientModel>> getClients({bool activeOnly = false});
  Future<ClientModel?> getClient(int id);
  Future<int> addClient({
    required String name,
    String? phone,
    String? notes,
    bool isActive,
    String? passportId,
    String? nationalId,
  });
  Future<void> updateClient(ClientModel client);
  Future<void> deleteClient(int id);

  Future<List<TransactionModel>> getClientTransactions(int clientId);
  Future<List<PaymentModel>> getClientPayments(int clientId);
  Future<List<TransactionItemModel>> getClientItems(int clientId);
  Future<PartyBalanceModel> getClientBalance(int clientId);
}
