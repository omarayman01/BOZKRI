import 'package:drift/drift.dart';

import '../../../../model/item_type_field_model.dart';
import '../../../../model/item_type_model.dart';
import '../app_database.dart';
import '../mappers.dart';
import '../tables.dart';

part 'item_types_dao.g.dart';

@DriftAccessor(tables: <Type>[ItemTypes, ItemTypeFields, Items])
class ItemTypesDao extends DatabaseAccessor<AppDatabase>
    with _$ItemTypesDaoMixin {
  ItemTypesDao(super.db);

  /// Every type with its ordered field schema. Adding a type or a field here
  /// requires no code change anywhere in the UI.
  Future<List<ItemTypeModel>> getAllWithFields() async {
    final List<ItemTypeRow> typeRows = await (select(itemTypes)
          ..orderBy(<OrderClauseGenerator<$ItemTypesTable>>[
            (($ItemTypesTable t) => OrderingTerm.asc(t.name)),
          ]))
        .get();
    if (typeRows.isEmpty) return <ItemTypeModel>[];

    final List<ItemTypeFieldRow> fieldRows = await (select(itemTypeFields)
          ..orderBy(<OrderClauseGenerator<$ItemTypeFieldsTable>>[
            (($ItemTypeFieldsTable t) => OrderingTerm.asc(t.sortOrder)),
            (($ItemTypeFieldsTable t) => OrderingTerm.asc(t.id)),
          ]))
        .get();

    final Map<int, List<ItemTypeFieldModel>> byType =
        <int, List<ItemTypeFieldModel>>{};
    for (final ItemTypeFieldRow row in fieldRows) {
      byType
          .putIfAbsent(row.itemTypeId, () => <ItemTypeFieldModel>[])
          .add(row.toModel());
    }

    return typeRows
        .map((ItemTypeRow t) => t.toModel(
            fields: byType[t.id] ?? const <ItemTypeFieldModel>[]))
        .toList();
  }

  Future<ItemTypeModel?> getById(int id) async {
    final ItemTypeRow? row = await (select(itemTypes)
          ..where(($ItemTypesTable t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return row.toModel(fields: await getFields(id));
  }

  Future<List<ItemTypeFieldModel>> getFields(int itemTypeId) async {
    final List<ItemTypeFieldRow> rows = await (select(itemTypeFields)
          ..where(($ItemTypeFieldsTable t) => t.itemTypeId.equals(itemTypeId))
          ..orderBy(<OrderClauseGenerator<$ItemTypeFieldsTable>>[
            (($ItemTypeFieldsTable t) => OrderingTerm.asc(t.sortOrder)),
            (($ItemTypeFieldsTable t) => OrderingTerm.asc(t.id)),
          ]))
        .get();
    return rows.map((ItemTypeFieldRow r) => r.toModel()).toList();
  }

  Future<int> insertType(String name) => into(itemTypes).insert(
        ItemTypesCompanion.insert(name: name, createdAt: DateTime.now()),
      );

  Future<int> renameType(int id, String name) =>
      (update(itemTypes)..where(($ItemTypesTable t) => t.id.equals(id)))
          .write(ItemTypesCompanion(
        name: Value<String>(name),
        updatedAt: Value<DateTime>(DateTime.now()),
      ));

  Future<int> deleteType(int id) =>
      (delete(itemTypes)..where(($ItemTypesTable t) => t.id.equals(id))).go();

  Future<int> countItemsOfType(int itemTypeId) async {
    final QueryRow row = await customSelect(
      'SELECT COUNT(*) AS c FROM items WHERE item_type_id = ?',
      variables: <Variable<Object>>[Variable<int>(itemTypeId)],
      readsFrom: <ResultSetImplementation<HasResultSet, Object>>{items},
    ).getSingle();
    return row.read<int>('c');
  }

  Future<int> insertField({
    required int itemTypeId,
    required String fieldName,
    required FieldType fieldType,
    bool isRequired = false,
    int sortOrder = 0,
  }) {
    return into(itemTypeFields).insert(
      ItemTypeFieldsCompanion.insert(
        itemTypeId: itemTypeId,
        fieldName: fieldName,
        fieldType: fieldType.name,
        isRequired: Value<bool>(isRequired),
        sortOrder: Value<int>(sortOrder),
      ),
    );
  }

  Future<int> updateField(ItemTypeFieldModel field) {
    return (update(itemTypeFields)
          ..where(($ItemTypeFieldsTable t) => t.id.equals(field.id)))
        .write(
      ItemTypeFieldsCompanion(
        fieldName: Value<String>(field.fieldName),
        fieldType: Value<String>(field.fieldType.name),
        isRequired: Value<bool>(field.isRequired),
        sortOrder: Value<int>(field.sortOrder),
        updatedAt: Value<DateTime>(DateTime.now()),
      ),
    );
  }

  /// Deleting a field cascades its stored values (item_field_values FK).
  Future<int> deleteField(int fieldId) => (delete(itemTypeFields)
        ..where(($ItemTypeFieldsTable t) => t.id.equals(fieldId)))
      .go();

  Future<void> reorderFields(List<int> orderedFieldIds) async {
    await batch((Batch b) {
      for (int i = 0; i < orderedFieldIds.length; i++) {
        b.update(
          itemTypeFields,
          ItemTypeFieldsCompanion(
            sortOrder: Value<int>(i),
            updatedAt: Value<DateTime>(DateTime.now()),
          ),
          where: ($ItemTypeFieldsTable t) => t.id.equals(orderedFieldIds[i]),
        );
      }
    });
  }
}
