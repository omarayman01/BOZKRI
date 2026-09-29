import 'package:drift/drift.dart';

import '../../../../model/item_field_value_model.dart';
import '../../../../model/item_model.dart';
import '../app_database.dart';
import '../mappers.dart';
import '../tables.dart';

part 'items_dao.g.dart';

@DriftAccessor(tables: <Type>[
  Items,
  ItemFieldValues,
  ItemTypes,
  ItemTypeFields,
  Suppliers,
  TransactionItems,
])
class ItemsDao extends DatabaseAccessor<AppDatabase> with _$ItemsDaoMixin {
  ItemsDao(super.db);

  static const String _selectItems = '''
    SELECT i.*, it.name AS type_name, s.name AS supplier_name
    FROM items i
    JOIN item_types it ON it.id = i.item_type_id
    JOIN suppliers s ON s.id = i.supplier_id
  ''';

  Future<List<ItemModel>> getAll({bool activeOnly = false}) =>
      _query('$_selectItems ${activeOnly ? 'WHERE i.is_active = 1' : ''} '
          'ORDER BY i.label');

  Future<ItemModel?> getById(int id) async {
    final List<ItemModel> result = await _query(
      '$_selectItems WHERE i.id = ?',
      <Variable<Object>>[Variable<int>(id)],
    );
    return result.isEmpty ? null : result.first;
  }

  Future<List<ItemModel>> getBySupplier(int supplierId) => _query(
        '$_selectItems WHERE i.supplier_id = ? ORDER BY i.label',
        <Variable<Object>>[Variable<int>(supplierId)],
      );

  /// Items selectable in the deal line editor for a given supplier:
  /// active, not expired, and either reusable or still available.
  Future<List<ItemModel>> getAvailableForSupplier(int supplierId) => _query(
        '''
        $_selectItems
        WHERE i.supplier_id = ?
          AND i.is_active = 1
          AND (i.expiry_date IS NULL OR i.expiry_date >= ?)
          AND (i.is_single_use = 0 OR i.is_available = 1)
        ORDER BY i.label
        ''',
        <Variable<Object>>[
          Variable<int>(supplierId),
          Variable<DateTime>(DateTime.now()),
        ],
      );

  /// Items carrying an expiry date at or before [threshold], for the
  /// expiry provider and dashboard panel.
  Future<List<ItemModel>> getExpiringBefore(DateTime threshold) => _query(
        '''
        $_selectItems
        WHERE i.is_active = 1
          AND i.expiry_date IS NOT NULL
          AND i.expiry_date <= ?
        ORDER BY i.expiry_date
        ''',
        <Variable<Object>>[Variable<DateTime>(threshold)],
      );

  Future<List<ItemModel>> _query(String sql,
      [List<Variable<Object>> vars = const <Variable<Object>>[]]) async {
    final List<QueryRow> rows = await customSelect(
      sql,
      variables: vars,
      readsFrom: <ResultSetImplementation<HasResultSet, Object>>{
        items,
        itemTypes,
        suppliers,
      },
    ).get();

    if (rows.isEmpty) return <ItemModel>[];

    final List<int> ids = rows.map((QueryRow r) => r.read<int>('id')).toList();
    final Map<int, List<ItemFieldValueModel>> values =
        await _fieldValuesFor(ids);

    return rows.map((QueryRow r) {
      final int id = r.read<int>('id');
      return items.map(r.data, tablePrefix: null).toModel(
            fieldValues: values[id] ?? const <ItemFieldValueModel>[],
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

  /// Inserts an item and its dynamic field values atomically.
  /// [fieldValues] maps item_type_fields.id -> raw text value.
  Future<int> createItem({
    required int itemTypeId,
    required int supplierId,
    required String label,
    double? defaultCost,
    double? defaultPrice,
    DateTime? expiryDate,
    bool isSingleUse = false,
    bool isAvailable = true,
    String? notes,
    bool isActive = true,
    Map<int, String> fieldValues = const <int, String>{},
  }) {
    return transaction(() async {
      final int itemId = await into(items).insert(
        ItemsCompanion.insert(
          itemTypeId: itemTypeId,
          supplierId: supplierId,
          label: label,
          defaultCost: Value<double?>(defaultCost),
          defaultPrice: Value<double?>(defaultPrice),
          expiryDate: Value<DateTime?>(expiryDate),
          isSingleUse: Value<bool>(isSingleUse),
          isAvailable: Value<bool>(isAvailable),
          notes: Value<String?>(notes),
          isActive: Value<bool>(isActive),
          createdAt: DateTime.now(),
        ),
      );
      await _writeFieldValues(itemId, fieldValues);
      return itemId;
    });
  }

  /// Editing an item's defaults never touches past deals: transaction_items
  /// keep their own unitCost / unitPrice snapshots.
  Future<void> updateItem({
    required int id,
    required int itemTypeId,
    required int supplierId,
    required String label,
    double? defaultCost,
    double? defaultPrice,
    DateTime? expiryDate,
    required bool isSingleUse,
    required bool isAvailable,
    String? notes,
    required bool isActive,
    Map<int, String> fieldValues = const <int, String>{},
  }) {
    return transaction(() async {
      await (update(items)..where(($ItemsTable t) => t.id.equals(id))).write(
        ItemsCompanion(
          itemTypeId: Value<int>(itemTypeId),
          supplierId: Value<int>(supplierId),
          label: Value<String>(label),
          defaultCost: Value<double?>(defaultCost),
          defaultPrice: Value<double?>(defaultPrice),
          expiryDate: Value<DateTime?>(expiryDate),
          isSingleUse: Value<bool>(isSingleUse),
          isAvailable: Value<bool>(isAvailable),
          notes: Value<String?>(notes),
          isActive: Value<bool>(isActive),
          updatedAt: Value<DateTime>(DateTime.now()),
        ),
      );
      await (delete(itemFieldValues)
            ..where(($ItemFieldValuesTable t) => t.itemId.equals(id)))
          .go();
      await _writeFieldValues(id, fieldValues);
    });
  }

  Future<void> _writeFieldValues(int itemId, Map<int, String> values) async {
    if (values.isEmpty) return;
    await batch((Batch b) {
      b.insertAll(
        itemFieldValues,
        values.entries
            .map((MapEntry<int, String> e) => ItemFieldValuesCompanion.insert(
                  itemId: itemId,
                  fieldId: e.key,
                  value: e.value,
                ))
            .toList(),
      );
    });
  }

  Future<int> deleteItem(int id) =>
      (delete(items)..where(($ItemsTable t) => t.id.equals(id))).go();

  Future<int> countUsagesOf(int itemId) async {
    final QueryRow row = await customSelect(
      'SELECT COUNT(*) AS c FROM transaction_items WHERE item_id = ?',
      variables: <Variable<Object>>[Variable<int>(itemId)],
      readsFrom: <ResultSetImplementation<HasResultSet, Object>>{
        transactionItems
      },
    ).getSingle();
    return row.read<int>('c');
  }

  /// Availability flips only ever apply to single-use items.
  Future<int> setAvailability(int itemId, bool available) {
    return (update(items)
          ..where(($ItemsTable t) =>
              t.id.equals(itemId) & t.isSingleUse.equals(true)))
        .write(ItemsCompanion(
          isAvailable: Value<bool>(available),
          updatedAt: Value<DateTime>(DateTime.now()),
        ));
  }
}
