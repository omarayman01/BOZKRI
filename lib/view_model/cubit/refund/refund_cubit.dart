import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../model/refund_model.dart';
import '../../../model/transaction_item_model.dart';
import '../../../model/transaction_with_items_model.dart';
import '../../database/local/daos/refunds_dao.dart';
import '../../errors/failure.dart';
import '../../provider/items_cache_provider.dart';
import '../../repos/refunds_repo.dart';
import '../../repos/transactions_repo.dart';
import 'refund_state.dart';

/// Drives the refund screen: computes refundable quantities and commits the
/// refund in a single Drift transaction (rows + status + single-use release).
class RefundCubit extends Cubit<RefundState> {
  RefundCubit(this._refundsRepo, this._transactionsRepo)
      : super(const RefundState());

  final RefundsRepo _refundsRepo;
  final TransactionsRepo _transactionsRepo;

  Future<void> load(int transactionId) async {
    emit(state.copyWith(status: RefundStatus.loading, clearError: true));
    try {
      final TransactionWithItemsModel? deal =
          await _transactionsRepo.getDeal(transactionId);
      if (deal == null) {
        emit(state.copyWith(
          status: RefundStatus.failure,
          errorMessage: 'This deal no longer exists.',
        ));
        return;
      }
      final Map<int, int> refunded =
          await _refundsRepo.refundedQtyByLine(transactionId);
      final List<RefundModel> refunds =
          await _refundsRepo.getForTransaction(transactionId);

      emit(state.copyWith(
        status: RefundStatus.ready,
        deal: deal,
        refunds: refunds,
        refundedQty: refunded,
        selectedQty: <int, int>{},
      ));
    } on Failure catch (failure) {
      emit(state.copyWith(
        status: RefundStatus.failure,
        errorMessage: failure.message,
      ));
    }
  }

  void setLineQty(int transactionItemId, int qty) {
    final TransactionWithItemsModel? deal = state.deal;
    if (deal == null) return;

    TransactionItemModel? line;
    for (final TransactionItemModel candidate in deal.items) {
      if (candidate.id == transactionItemId) {
        line = candidate;
        break;
      }
    }
    if (line == null) return;

    final int max = line.qty - (state.refundedQty[transactionItemId] ?? 0);
    final int clamped = qty.clamp(0, max < 0 ? 0 : max);

    final Map<int, int> updated = Map<int, int>.from(state.selectedQty);
    if (clamped == 0) {
      updated.remove(transactionItemId);
    } else {
      updated[transactionItemId] = clamped;
    }
    emit(state.copyWith(selectedQty: updated, clearError: true));
  }

  /// Selects every remaining unit on every line.
  void selectFull() {
    final TransactionWithItemsModel? deal = state.deal;
    if (deal == null) return;
    final Map<int, int> full = <int, int>{};
    for (final TransactionItemModel line in deal.items) {
      final int remaining = line.qty - (state.refundedQty[line.id] ?? 0);
      if (remaining > 0) full[line.id] = remaining;
    }
    emit(state.copyWith(selectedQty: full, clearError: true));
  }

  void clearSelection() =>
      emit(state.copyWith(selectedQty: <int, int>{}, clearError: true));

  void setReason(String? reason) => emit(state.copyWith(reason: reason));

  /// Commits the refund. A crash mid-flow leaves no partial refund because the
  /// DAO wraps every write in one Drift transaction.
  Future<bool> submit({ItemsCacheProvider? itemsCache}) async {
    final TransactionWithItemsModel? deal = state.deal;
    if (deal == null || !state.hasSelection) {
      emit(state.copyWith(errorMessage: 'Select at least one line to refund.'));
      return false;
    }

    emit(state.copyWith(status: RefundStatus.submitting, clearError: true));
    try {
      final List<RefundLineInput> lines = state.selectedQty.entries
          .map((MapEntry<int, int> e) =>
              RefundLineInput(transactionItemId: e.key, qty: e.value))
          .toList();

      await _refundsRepo.commitRefund(
        transactionId: deal.id,
        lines: lines,
        reason: state.reason,
      );

      // Reflect released single-use items in the shared cache.
      if (itemsCache != null) {
        final Map<int, int> after =
            await _refundsRepo.refundedQtyByLine(deal.id);
        for (final TransactionItemModel line in deal.items) {
          if (line.isSingleUse && (after[line.id] ?? 0) >= line.qty) {
            itemsCache.setAvailability(line.itemId, true);
          }
        }
      }

      await load(deal.id);
      emit(state.copyWith(status: RefundStatus.success));
      return true;
    } on Failure catch (failure) {
      emit(state.copyWith(
        status: RefundStatus.failure,
        errorMessage: failure.message,
      ));
      return false;
    }
  }

  Future<bool> deleteRefund(int refundId) async {
    final int? dealId = state.deal?.id;
    if (dealId == null) return false;
    emit(state.copyWith(status: RefundStatus.submitting, clearError: true));
    try {
      await _refundsRepo.deleteRefund(refundId);
      await load(dealId);
      return true;
    } on Failure catch (failure) {
      emit(state.copyWith(
        status: RefundStatus.failure,
        errorMessage: failure.message,
      ));
      return false;
    }
  }

  void clearError() => emit(state.copyWith(clearError: true));
}
