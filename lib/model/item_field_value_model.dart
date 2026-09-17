import 'package:freezed_annotation/freezed_annotation.dart';

part 'item_field_value_model.freezed.dart';

@freezed
class ItemFieldValueModel with _$ItemFieldValueModel {
  const factory ItemFieldValueModel({
    required int id,
    required int itemId,
    required int fieldId,
    required String value,
  }) = _ItemFieldValueModel;
}
