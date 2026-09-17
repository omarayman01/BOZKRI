import 'package:freezed_annotation/freezed_annotation.dart';

part 'client_model.freezed.dart';

@freezed
class ClientModel with _$ClientModel {
  const factory ClientModel({
    required int id,
    required String name,
    String? phone,
    String? notes,
    @Default(true) bool isActive,
    required DateTime createdAt,
    String? passportId,
    String? nationalId,
  }) = _ClientModel;
}
