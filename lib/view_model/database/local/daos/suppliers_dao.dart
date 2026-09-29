import 'package:drift/drift.dart';

import '../../../../model/item_field_value_model.dart';
import '../../../../model/item_model.dart';
import '../../../../model/party_balance_model.dart';
import '../../../../model/payment_model.dart';
import '../../../../model/supplier_model.dart';
import '../../../../model/transaction_model.dart';
import '../app_database.dart';
import '../mappers.dart';
import '../tables.dart';

part 'suppliers_dao.g.dart';

@DriftAccessor(tables: <Type>[
  Suppliers,
  Items,
  ItemFieldValues,
  ItemTypes,
  Transactions,
  TransactionItems,
  Payments,
  Refunds,
  RefundItems,
  Clients,
])
class SuppliersDao extends DatabaseAccessor<AppDatabase>
    with _$SuppliersDaoMixin {
  SuppliersDao(super.db);

  // ---- CRUD ----

  Future<List<SupplierModel>> getAll({bool activeOnly = false}) async {
    final SimpleSelectStatement<$SuppliersTable, SupplierRow> query =
        select(suppliers)
          ..orderBy(<OrderClauseGenerator<$SuppliersTable>>[
            (($SuppliersTable t) => OrderingTerm.asc(t.name)),
          ]);
    if (activeOnly) {
      query.where(($SuppliersTable t) => t.isActive.equals(true));
    }
    final List<SupplierRow> rows = await query.get();
    return rows.map((SupplierRow r) => r.toModel()).toList();
  }

  Future<SupplierModel?> getById(int id) async {
    final SupplierRow? row = await (select(suppliers)
          ..where(($SuppliersTable t) => t.id.equals(id)))
        .getSingleOrNull();
    return row?.toModel();
  }

  Future<int> insertSupplier({
    required String name,
    String? phone,
    String? notes,
    bool isActive = true,
  }) {
    return into(suppliers).insert(
      SuppliersCompanion.insert(
        name: name,
        phone: Value<String?>(phone),
        notes: Value<String?>(notes),
        isActive: Value<bool>(isActive),
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<bool> updateSupplier(SupplierModel supplier) {
    return update(suppliers).replace(
      SupplierRow(
        id: supplier.id,
        name: supplier.name,
        phone: supplier.phone,
        notes: supplier.notes,
        isActive: supplier.isActive,
        createdAt: supplier.createdAt,
        updatedAt: DateTime.now(),
        isSystemSupplier: supplier.isSystemSupplier,
      ),
    );
  }

  /// The single seeded "بوزكري (بدون مورد)" supplier a car is assigned to
  /// when it has no real supplier. Always present (seeded at db creation
  /// and by the schema-11 migration).
  Future<int> getSystemSupplierId() async {
    final SupplierRow row = await (select(suppliers)
          ..where(($SuppliersTable t) => t.isSystemSupplier.equals(true)))
        .getSingle();
    return row.id;
  }

  Future<int> deleteSupplier(int id) =>
      (delete(suppliers)..where(($SuppliersTable t) => t.id.equals(id))).go();

  Future<int> countItemsFor(int supplierId) async {
    final QueryRow row = await customSelect(
      'SELECT COUNT(*) AS c FROM items WHERE supplier_id = ?',
      variables: <Variable<Object>>[Variable<int>(supplierId)],
      readsFrom: <ResultSetImplementation<HasResultSet, Object>>{items},
    ).getSingle();
    return row.read<int>('c');
  }

  // ---- Detail drill-down ----

  /// Items this supplier provides, with their dynamic field values.
  Future<List<ItemModel>> getSupplierItems(
    int supplierId, {
    bool activeOnly = false,
  }) async {
    final List<QueryRow> rows = await customSelect(
      '''
      SELECT i.*, it.name AS type_name, s.name AS supplier_name
      FROM items i
      JOIN item_types it ON it.id = i.item_type_id
      JOIN suppliers s ON s.id = i.supplier_id
      WHERE i.supplier_id = ? ${activeOnly ? 'AND i.is_active = 1' : ''}
      ORDER BY i.label
      ''',
      variables: <Variable<Object>>[Variable<int>(supplierId)],
      readsFrom: <ResultSetImplementation<HasResultSet, Object>>{
        items,
        itemTypes,
        suppliers,
      },
    ).get();

    if (rows.isEmpty) return <ItemModel>[];

    final List<int> itemIds =
        rows.map((QueryRow r) => r.read<int>('id')).toList();
    final Map<int, List<ItemFieldValueModel>> valuesByItem =
        await _fieldValuesFor(itemIds);

    return rows.map((QueryRow r) {
      final int id = r.read<int>('id');
      return items.map(r.data, tablePrefix: null).toModel(
            fieldValues: valuesByItem[id] ?? const <ItemFieldValueModel>[],
            itemTypeName: r.read<String>('type_name'),
            supplierName: r.read<String>('supplier_name'),
          );
    }).toList();
  }

  Future<Map<int, List<ItemFieldValueModel>>> _fieldValuesFor(
      List<int> itemIds) async {
    if (itemIds.isEmpty) return <int, List<ItemFieldValueModel>>{};
    final List<ItemFieldValueRow> rows = await (select(itemFieldValues)
          ..where(($ItemFieldValuesTable t) => t.itemId.isIn(itemIds)))
        .get();
    final Map<int, List<ItemFieldValueModel>> map =
        <int, List<ItemFieldValueModel>>{};
    for (final ItemFieldValueRow row in rows) {
      map.putIfAbsent(row.itemId, () => <ItemFieldValueModel>[])
          .add(row.toModel());
    }
    return map;
  }

  /// Deals that contain at least one line from this supplier, together with
  /// this supplier's cost slice of each deal.
  Future<List<SupplierTransactionSlice>> getSupplierTransactions(
      int supplierId) async {
    final List<QueryRow> rows = await customSelect(
      '''
      SELECT t.*, c.name AS client_name,
        (SELECT COALESCE(SUM(ti.unit_cost * ti.qty), 0)
           FROM transaction_items ti
          WHERE ti.transaction_id = t.id AND ti.supplier_id = ?) AS slice_cost,
        (SELECT COALESCE(SUM(ri.unit_cost * ri.qty), 0)
           FROM refund_items ri
           JOIN transaction_items ti2 ON ti2.id = ri.transaction_item_id
          WHERE ti2.transaction_id = t.id
            AND ti2.supplier_id = ?) AS slice_refunded,
        (SELECT COALESCE(SUM(p.amount), 0) FROM payments p
          WHERE p.transaction_id = t.id AND p.party = 'supplier'
            AND p.supplier_id = ?) AS slice_paid
      FROM transactions t
      JOIN clients c ON c.id = t.client_id
      WHERE EXISTS (SELECT 1 FROM transaction_items ti
                     WHERE ti.transaction_id = t.id AND ti.supplier_id = ?)
      ORDER BY t.date_time DESC
      ''',
      variables: <Variable<Object>>[
        Variable<int>(supplierId),
        Variable<int>(supplierId),
        Variable<int>(supplierId),
        Variable<int>(supplierId),
      ],
      readsFrom: <ResultSetImplementation<HasResultSet, Object>>{
        transactions,
        transactionItems,
        refundItems,
        payments,
        clients,
      },
    ).get();

    return rows.map((QueryRow r) {
      final TransactionModel tx = transactions
          .map(r.data, tablePrefix: null)
          .toModel(clientName: r.read<String>('client_name'));
      return SupplierTransactionSlice(
        transaction: tx,
        supplierCost:
            r.read<double>('slice_cost') - r.read<double>('slice_refunded'),
        supplierPaid: r.read<double>('slice_paid'),
      );
    }).toList();
  }

  /// Payments made to this supplier across all deals.
  Future<List<PaymentModel>> getSupplierPayments(int supplierId) async {
    final List<QueryRow> rows = await customSelect(
      '''
      SELECT p.*, s.name AS supplier_name
      FROM payments p
      JOIN suppliers s ON s.id = p.supplier_id
      WHERE p.party = 'supplier' AND p.supplier_id = ?
      ORDER BY p.date_time DESC
      ''',
      variables: <Variable<Object>>[Variable<int>(supplierId)],
      readsFrom: <ResultSetImplementation<HasResultSet, Object>>{
        payments,
        suppliers,
      },
    ).get();

    return rows
        .map((QueryRow r) => payments
            .map(r.data, tablePrefix: null)
            .toModel(supplierName: r.read<String>('supplier_name')))
        .toList();
  }

  /// Payable = Σ this supplier's line costs − Σ refunded cost on those lines;
  /// settled = Σ payments attributed to this supplier.
  Future<PartyBalanceModel> getSupplierBalance(int supplierId) async {
    final QueryRow row = await customSelect(
      '''
      SELECT
        (SELECT COALESCE(SUM(ti.unit_cost * ti.qty), 0)
           FROM transaction_items ti WHERE ti.supplier_id = ?) AS cost,
        (SELECT COALESCE(SUM(ri.unit_cost * ri.qty), 0)
           FROM refund_items ri
           JOIN transaction_items ti ON ti.id = ri.transaction_item_id
          WHERE ti.supplier_id = ?) AS refunded,
        (SELECT COALESCE(SUM(p.amount), 0) FROM payments p
          WHERE p.party = 'supplier' AND p.supplier_id = ?) AS paid,
        (SELECT COUNT(DISTINCT ti.transaction_id) FROM transaction_items ti
          WHERE ti.supplier_id = ?) AS deals,
        (SELECT name FROM suppliers WHERE id = ?) AS party_name
      ''',
      variables: <Variable<Object>>[
        Variable<int>(supplierId),
        Variable<int>(supplierId),
        Variable<int>(supplierId),
        Variable<int>(supplierId),
        Variable<int>(supplierId),
      ],
      readsFrom: <ResultSetImplementation<HasResultSet, Object>>{
        transactionItems,
        refundItems,
        payments,
        suppliers,
      },
    ).getSingle();

    return PartyBalanceModel(
      partyId: supplierId,
      partyName: row.read<String?>('party_name') ?? '',
      totalOwed: row.read<double>('cost') - row.read<double>('refunded'),
      totalSettled: row.read<double>('paid'),
      transactionCount: row.read<int>('deals'),
    );
  }
}

/// One deal as seen from a single supplier's perspective.
class SupplierTransactionSlice {
  const SupplierTransactionSlice({
    required this.transaction,
    required this.supplierCost,
    required this.supplierPaid,
  });

  final TransactionModel transaction;

  /// This supplier's cost inside the deal, net of refunded cost.
  final double supplierCost;

  /// Paid to this supplier for this deal.
  final double supplierPaid;

  double get outstanding => supplierCost - supplierPaid;
}
