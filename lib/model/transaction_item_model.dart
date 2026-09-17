import 'package:freezed_annotation/freezed_annotation.dart';

import 'transaction_model.dart';

part 'transaction_item_model.freezed.dart';

/// حالة العقد: whether a car (or any per-day line) has been returned and
/// settled yet.
enum LineStatus {
  active,
  returned;

  static LineStatus fromName(String value) => LineStatus.values.firstWhere(
        (LineStatus e) => e.name == value,
        orElse: () => LineStatus.active,
      );
}

/// A single deal line. [unitCost] and [unitPrice] are snapshots captured at
/// deal time and must never be re-read from the live item.
@freezed
class TransactionItemModel with _$TransactionItemModel {
  const TransactionItemModel._();

  const factory TransactionItemModel({
    required int id,
    required int transactionId,
    required int itemId,
    required int supplierId,
    required DealType dealType,
    @Default(1) int qty,
    required double unitCost,
    required double unitPrice,
    required double lineTotal,
    DateTime? rentStart,
    DateTime? rentEnd,
    DateTime? expiryDate,
    String? notes,
    String? itemLabel,
    String? supplierName,
    String? supplierPhone,
    @Default(false) bool isSingleUse,
    @Default(0) int refundedQty,
    double? pricePerDay,
    double? costPerDay,
    int? days,
    double? allowedKmPerDay,
    double? extraKmRate,
    double? pickupKilometer,
    double? returnKilometer,
    double? extraKmCharge,
    @Default(LineStatus.active) LineStatus lineStatus,
  }) = _TransactionItemModel;

  double get lineCost => unitCost * qty;
  double get unitProfit => unitPrice - unitCost;
  double get lineProfit => (unitPrice - unitCost) * qty;
  int get refundableQty => qty - refundedQty;
  bool get isFullyRefunded => refundedQty >= qty;

  /// Cars priced per rental day rather than a flat amount. `unitPrice`/
  /// `unitCost`/`qty` already equal `pricePerDay`/`costPerDay`/`days` for
  /// these lines, so every money getter above keeps working unchanged.
  bool get isPerDay => pricePerDay != null;

  bool get isReturned => lineStatus == LineStatus.returned;

  /// `lineTotal` plus the extra-kilometer charge fixed at return time. Equal
  /// to `lineTotal` for lines with no settlement (or none needed).
  double get finalLineTotal => lineTotal + (extraKmCharge ?? 0);

  bool get isExpired =>
      expiryDate != null && expiryDate!.isBefore(DateTime.now());
}
