import 'package:freezed_annotation/freezed_annotation.dart';

part 'refund_item_model.freezed.dart';

/// Snapshot values are copied verbatim from the original transaction item.
@freezed
class RefundItemModel with _$RefundItemModel {
  const RefundItemModel._();

  const factory RefundItemModel({
    required int id,
    required int refundId,
    required int transactionItemId,
    required int itemId,
    required int qty,
    required double unitCost,
    required double unitPrice,
    String? itemLabel,
  }) = _RefundItemModel;

  double get refundedRevenue => unitPrice * qty;
  double get refundedCost => unitCost * qty;
}
