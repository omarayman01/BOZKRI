import 'package:equatable/equatable.dart';

import '../../../model/refund_model.dart';
import '../../../model/transaction_item_model.dart';
import '../../../model/transaction_with_items_model.dart';

enum RefundStatus { initial, loading, ready, submitting, success, failure }

class RefundState extends Equatable {
  const RefundState({
    this.status = RefundStatus.initial,
    this.deal,
    this.refunds = const <RefundModel>[],
    this.selectedQty = const <int, int>{},
    this.refundedQty = const <int, int>{},
    this.reason,
    this.errorMessage,
  });

  final RefundStatus status;
  final TransactionWithItemsModel? deal;
  final List<RefundModel> refunds;

  /// transaction_item_id -> qty the user chose to refund now.
  final Map<int, int> selectedQty;

  /// transaction_item_id -> qty already refunded previously.
  final Map<int, int> refundedQty;

  final String? reason;
  final String? errorMessage;

  bool get isLoading => status == RefundStatus.loading;
  bool get isSubmitting => status == RefundStatus.submitting;
  bool get isFailure => status == RefundStatus.failure;

  /// Refundable qty for a line = original qty − already refunded.
  int refundableFor(int lineId, int originalQty) =>
      originalQty - (refundedQty[lineId] ?? 0);

  bool get hasSelection =>
      selectedQty.values.any((int qty) => qty > 0);

  double get refundTotal {
    final TransactionWithItemsModel? d = deal;
    if (d == null) return 0;
    double sum = 0;
    for (final TransactionItemModel line in d.items) {
      final int qty = selectedQty[line.id] ?? 0;
      sum += line.unitPrice * qty;
    }
    return sum;
  }

  double get refundCostTotal {
    final TransactionWithItemsModel? d = deal;
    if (d == null) return 0;
    double sum = 0;
    for (final TransactionItemModel line in d.items) {
      final int qty = selectedQty[line.id] ?? 0;
      sum += line.unitCost * qty;
    }
    return sum;
  }

  RefundState copyWith({
    RefundStatus? status,
    TransactionWithItemsModel? deal,
    List<RefundModel>? refunds,
    Map<int, int>? selectedQty,
    Map<int, int>? refundedQty,
    String? reason,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RefundState(
      status: status ?? this.status,
      deal: deal ?? this.deal,
      refunds: refunds ?? this.refunds,
      selectedQty: selectedQty ?? this.selectedQty,
      refundedQty: refundedQty ?? this.refundedQty,
      reason: reason ?? this.reason,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => <Object?>[
        status,
        deal,
        refunds,
        selectedQty,
        refundedQty,
        reason,
        errorMessage,
      ];
}
