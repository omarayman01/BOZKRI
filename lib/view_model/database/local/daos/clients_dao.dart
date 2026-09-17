import 'package:drift/drift.dart';

import '../../../../model/client_model.dart';
import '../../../../model/party_balance_model.dart';
import '../../../../model/payment_model.dart';
import '../../../../model/transaction_item_model.dart';
import '../../../../model/transaction_model.dart';
import '../app_database.dart';
import '../mappers.dart';
import '../tables.dart';

part 'clients_dao.g.dart';

@DriftAccessor(tables: <Type>[Clients, Transactions, TransactionItems, Payments, Refunds, Items])
class ClientsDao extends DatabaseAccessor<AppDatabase> with _$ClientsDaoMixin {
  ClientsDao(super.db);

  // ---- CRUD ----

  Future<List<ClientModel>> getAll({bool activeOnly = false}) async {
    final SimpleSelectStatement<$ClientsTable, ClientRow> query = select(clients)
      ..orderBy(<OrderClauseGenerator<$ClientsTable>>[
        (($ClientsTable t) => OrderingTerm.asc(t.name)),
      ]);
    if (activeOnly) {
      query.where(($ClientsTable t) => t.isActive.equals(true));
    }
    final List<ClientRow> rows = await query.get();
    return rows.map((ClientRow r) => r.toModel()).toList();
  }

  Future<ClientModel?> getById(int id) async {
    final ClientRow? row = await (select(clients)
          ..where(($ClientsTable t) => t.id.equals(id)))
        .getSingleOrNull();
    return row?.toModel();
  }

  Future<int> insertClient({
    required String name,
    String? phone,
    String? notes,
    bool isActive = true,
    String? passportId,
    String? nationalId,
  }) {
    return into(clients).insert(
      ClientsCompanion.insert(
        name: name,
        phone: Value<String?>(phone),
        notes: Value<String?>(notes),
        isActive: Value<bool>(isActive),
        createdAt: DateTime.now(),
        passportId: Value<String?>(passportId),
        nationalId: Value<String?>(nationalId),
      ),
    );
  }

  Future<bool> updateClient(ClientModel client) {
    return update(clients).replace(
      ClientRow(
        id: client.id,
        name: client.name,
        phone: client.phone,
        notes: client.notes,
        isActive: client.isActive,
        createdAt: client.createdAt,
        passportId: client.passportId,
        nationalId: client.nationalId,
      ),
    );
  }

  Future<int> deleteClient(int id) =>
      (delete(clients)..where(($ClientsTable t) => t.id.equals(id))).go();

  Future<int> countTransactionsFor(int clientId) async {
    final QueryRow row = await customSelect(
      'SELECT COUNT(*) AS c FROM transactions WHERE client_id = ?',
      variables: <Variable<Object>>[Variable<int>(clientId)],
      readsFrom: <ResultSetImplementation<HasResultSet, Object>>{transactions},
    ).getSingle();
    return row.read<int>('c');
  }

  // ---- Detail drill-down ----

  /// Every deal belonging to this client, newest first.
  Future<List<TransactionModel>> getClientTransactions(int clientId) async {
    final List<TransactionRow> rows = await (select(transactions)
          ..where(($TransactionsTable t) => t.clientId.equals(clientId))
          ..orderBy(<OrderClauseGenerator<$TransactionsTable>>[
            (($TransactionsTable t) => OrderingTerm.desc(t.occurredAt)),
          ]))
        .get();
    final ClientModel? client = await getById(clientId);
    return rows
        .map((TransactionRow r) => r.toModel(clientName: client?.name))
        .toList();
  }

  /// Payments received from this client (party = client) across all deals.
  Future<List<PaymentModel>> getClientPayments(int clientId) async {
    final List<QueryRow> rows = await customSelect(
      '''
      SELECT p.*, c.name AS client_name
      FROM payments p
      JOIN transactions t ON t.id = p.transaction_id
      JOIN clients c ON c.id = t.client_id
      WHERE t.client_id = ? AND p.party = 'client'
      ORDER BY p.date_time DESC
      ''',
      variables: <Variable<Object>>[Variable<int>(clientId)],
      readsFrom: <ResultSetImplementation<HasResultSet, Object>>{
        payments,
        transactions,
        clients,
      },
    ).get();

    return rows
        .map((QueryRow r) => payments
            .map(r.data, tablePrefix: null)
            .toModel(clientName: r.read<String>('client_name')))
        .toList();
  }

  /// Line items this client took, with the client-side expiry date.
  Future<List<TransactionItemModel>> getClientItems(int clientId) async {
    final List<QueryRow> rows = await customSelect(
      '''
      SELECT ti.*, i.label AS item_label, i.is_single_use AS single_use,
             s.name AS supplier_name,
             COALESCE((SELECT SUM(ri.qty) FROM refund_items ri
                       WHERE ri.transaction_item_id = ti.id), 0) AS refunded_qty
      FROM transaction_items ti
      JOIN transactions t ON t.id = ti.transaction_id
      JOIN items i ON i.id = ti.item_id
      JOIN suppliers s ON s.id = ti.supplier_id
      WHERE t.client_id = ?
      ORDER BY t.date_time DESC
      ''',
      variables: <Variable<Object>>[Variable<int>(clientId)],
      readsFrom: <ResultSetImplementation<HasResultSet, Object>>{
        transactionItems,
        transactions,
        items,
        suppliers,
      },
    ).get();

    return rows.map((QueryRow r) {
      return transactionItems.map(r.data, tablePrefix: null).toModel(
            itemLabel: r.read<String>('item_label'),
            supplierName: r.read<String>('supplier_name'),
            isSingleUse: r.read<int>('single_use') == 1,
            refundedQty: r.read<int>('refunded_qty'),
          );
    }).toList();
  }

  /// Receivable = Σ transaction totals − Σ refunds (client side);
  /// settled = Σ client payments. Derived, never stored.
  Future<PartyBalanceModel> getClientBalance(int clientId) async {
    final QueryRow row = await customSelect(
      '''
      SELECT
        (SELECT COALESCE(SUM(t.total), 0) FROM transactions t
          WHERE t.client_id = ?) AS billed,
        (SELECT COALESCE(SUM(r.total_refunded), 0) FROM refunds r
          JOIN transactions t ON t.id = r.transaction_id
          WHERE t.client_id = ?) AS refunded,
        (SELECT COALESCE(SUM(p.amount), 0) FROM payments p
          JOIN transactions t ON t.id = p.transaction_id
          WHERE t.client_id = ? AND p.party = 'client') AS collected,
        (SELECT COUNT(*) FROM transactions t WHERE t.client_id = ?) AS deals,
        (SELECT name FROM clients WHERE id = ?) AS party_name
      ''',
      variables: <Variable<Object>>[
        Variable<int>(clientId),
        Variable<int>(clientId),
        Variable<int>(clientId),
        Variable<int>(clientId),
        Variable<int>(clientId),
      ],
      readsFrom: <ResultSetImplementation<HasResultSet, Object>>{
        transactions,
        refunds,
        payments,
        clients,
      },
    ).getSingle();

    return PartyBalanceModel(
      partyId: clientId,
      partyName: row.read<String?>('party_name') ?? '',
      totalOwed: row.read<double>('billed') - row.read<double>('refunded'),
      totalSettled: row.read<double>('collected'),
      transactionCount: row.read<int>('deals'),
    );
  }
}
