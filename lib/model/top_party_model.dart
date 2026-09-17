import 'package:freezed_annotation/freezed_annotation.dart';

part 'top_party_model.freezed.dart';

/// One entry in the dashboard "top clients" / "top suppliers" lists.
@freezed
class TopPartyModel with _$TopPartyModel {
  const factory TopPartyModel({
    required int id,
    required String name,
    @Default(0) double total,
    @Default(0) double profit,
    @Default(0) int dealCount,
  }) = _TopPartyModel;
}
