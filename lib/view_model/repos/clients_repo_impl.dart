import '../../model/client_model.dart';
import '../../model/party_balance_model.dart';
import '../../model/payment_model.dart';
import '../../model/transaction_item_model.dart';
import '../../model/transaction_model.dart';
import '../database/local/app_database.dart';
import '../database/local/daos/clients_dao.dart';
import '../errors/db_failure.dart';
import '../errors/error_handler.dart';
import 'clients_repo.dart';

class ClientsRepoImpl implements ClientsRepo {
  const ClientsRepoImpl(this._dao, this._db);

  final ClientsDao _dao;
  final AppDatabase _db;

  @override
  Future<List<ClientModel>> getClients({bool activeOnly = false}) =>
      guard(() => _dao.getAll(activeOnly: activeOnly));

  @override
  Future<ClientModel?> getClient(int id) => guard(() => _dao.getById(id));

  @override
  Future<int> addClient({
    required String name,
    String? phone,
    String? notes,
    bool isActive = true,
    String? passportId,
    String? nationalId,
    String? updatedBy,
  }) =>
      guard(() => _dao.insertClient(
            name: name.trim(),
            phone: phone?.trim(),
            notes: notes?.trim(),
            isActive: isActive,
            passportId: passportId?.trim(),
            nationalId: nationalId?.trim(),
            updatedBy: updatedBy,
          ));

  @override
  Future<void> updateClient(ClientModel client, {String? updatedBy}) =>
      guard(() => _dao.updateClient(client, updatedBy: updatedBy));

  @override
  Future<void> deleteClient(int id) => guard(() async {
        final int deals = await _dao.countTransactionsFor(id);
        if (deals > 0) {
          throw ConstraintFailure(
            'This client has $deals deal(s). Deactivate them instead of '
            'deleting, or delete their deals first.',
          );
        }
        await _db.syncLinksDao.recordPendingDeleteIfLinked('clients', id);
        await _dao.deleteClient(id);
      });

  @override
  Future<List<TransactionModel>> getClientTransactions(int clientId) =>
      guard(() => _dao.getClientTransactions(clientId));

  @override
  Future<List<PaymentModel>> getClientPayments(int clientId) =>
      guard(() => _dao.getClientPayments(clientId));

  @override
  Future<List<TransactionItemModel>> getClientItems(int clientId) =>
      guard(() => _dao.getClientItems(clientId));

  @override
  Future<PartyBalanceModel> getClientBalance(int clientId) =>
      guard(() => _dao.getClientBalance(clientId));
}
