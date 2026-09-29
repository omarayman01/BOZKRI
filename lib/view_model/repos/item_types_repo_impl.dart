import '../../model/item_type_field_model.dart';
import '../../model/item_type_model.dart';
import '../database/local/app_database.dart';
import '../database/local/daos/item_types_dao.dart';
import '../errors/db_failure.dart';
import '../errors/error_handler.dart';
import 'item_types_repo.dart';

class ItemTypesRepoImpl implements ItemTypesRepo {
  const ItemTypesRepoImpl(this._dao, this._db);

  final ItemTypesDao _dao;
  final AppDatabase _db;

  @override
  Future<List<ItemTypeModel>> getTypes() => guard(_dao.getAllWithFields);

  @override
  Future<ItemTypeModel?> getType(int id) => guard(() => _dao.getById(id));

  @override
  Future<List<ItemTypeFieldModel>> getFields(int itemTypeId) =>
      guard(() => _dao.getFields(itemTypeId));

  @override
  Future<int> addType(String name) => guard(() => _dao.insertType(name.trim()));

  @override
  Future<void> renameType(int id, String name) =>
      guard(() => _dao.renameType(id, name.trim()));

  @override
  Future<void> deleteType(int id) => guard(() async {
        final int used = await _dao.countItemsOfType(id);
        if (used > 0) {
          throw ConstraintFailure(
            'This type is used by $used item(s) and cannot be deleted.',
          );
        }
        await _db.syncLinksDao.recordPendingDeleteIfLinked('item_types', id);
        await _dao.deleteType(id);
      });

  @override
  Future<int> addField({
    required int itemTypeId,
    required String fieldName,
    required FieldType fieldType,
    bool isRequired = false,
    int sortOrder = 0,
  }) =>
      guard(() => _dao.insertField(
            itemTypeId: itemTypeId,
            fieldName: fieldName.trim(),
            fieldType: fieldType,
            isRequired: isRequired,
            sortOrder: sortOrder,
          ));

  @override
  Future<void> updateField(ItemTypeFieldModel field) =>
      guard(() => _dao.updateField(field));

  @override
  Future<void> deleteField(int fieldId) => guard(() async {
        await _db.syncLinksDao
            .recordPendingDeleteIfLinked('item_type_fields', fieldId);
        await _dao.deleteField(fieldId);
      });

  @override
  Future<void> reorderFields(List<int> orderedFieldIds) =>
      guard(() => _dao.reorderFields(orderedFieldIds));
}
