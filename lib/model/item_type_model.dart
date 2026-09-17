import 'package:freezed_annotation/freezed_annotation.dart';

import 'item_type_field_model.dart';

part 'item_type_model.freezed.dart';

@freezed
class ItemTypeModel with _$ItemTypeModel {
  const factory ItemTypeModel({
    required int id,
    required String name,
    required DateTime createdAt,
    @Default(<ItemTypeFieldModel>[]) List<ItemTypeFieldModel> fields,
  }) = _ItemTypeModel;
}
