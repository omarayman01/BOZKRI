import '../../model/item_type_field_model.dart';
import '../../model/item_type_model.dart';

abstract class ItemTypesRepo {
  Future<List<ItemTypeModel>> getTypes();
  Future<ItemTypeModel?> getType(int id);
  Future<List<ItemTypeFieldModel>> getFields(int itemTypeId);

  Future<int> addType(String name);
  Future<void> renameType(int id, String name);
  Future<void> deleteType(int id);

  Future<int> addField({
    required int itemTypeId,
    required String fieldName,
    required FieldType fieldType,
    bool isRequired,
    int sortOrder,
  });
  Future<void> updateField(ItemTypeFieldModel field);
  Future<void> deleteField(int fieldId);
  Future<void> reorderFields(List<int> orderedFieldIds);
}
