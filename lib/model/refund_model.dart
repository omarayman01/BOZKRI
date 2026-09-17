import 'package:freezed_annotation/freezed_annotation.dart';

import 'refund_item_model.dart';

part 'refund_model.freezed.dart';

@freezed
class RefundModel with _$RefundModel {
  const factory RefundModel({
    required int id,
    required int transactionId,
    required DateTime dateTime,
    required double totalRefunded,
    required double totalCostRefunded,
    String? reason,
    @Default(<RefundItemModel>[]) List<RefundItemModel> items,
  }) = _RefundModel;
}
