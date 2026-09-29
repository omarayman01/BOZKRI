import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../model/transaction_item_model.dart';
import '../../../model/transaction_with_items_model.dart';
import '../../database/local/daos/transactions_dao.dart';
import '../../errors/db_failure.dart';
import '../../errors/failure.dart';
import '../../provider/items_cache_provider.dart';
import '../../provider/transaction_draft_provider.dart';
import '../../repos/transactions_repo.dart';
import 'deals_state.dart';

/// Owns the deal list, detail load, and the atomic commit / edit / delete.
class DealsCubit extends Cubit<DealsState> {
  DealsCubit(this._repo) : super(const DealsState());

  final TransactionsRepo _repo;

  Future<void> loadDeals({DateTime? from, DateTime? to}) async {
    emit(state.copyWith(status: DealsStatus.loading, clearError: true));
    try {
      final List<TransactionWithItemsModel> deals =
          await _repo.getDeals(from: from, to: to);
      emit(state.copyWith(status: DealsStatus.success, deals: deals));
    } on Failure catch (failure) {
      emit(state.copyWith(
        status: DealsStatus.failure,
        errorMessage: failure.message,
      ));
    }
  }

  Future<void> loadDeal(int transactionId) async {
    emit(state.copyWith(status: DealsStatus.loading, clearError: true));
    try {
      final TransactionWithItemsModel? deal = await _repo.getDeal(transactionId);
      if (deal == null) {
        emit(state.copyWith(
          status: DealsStatus.failure,
          errorMessage: 'This deal no longer exists.',
        ));
        return;
      }
      emit(state.copyWith(status: DealsStatus.success, selectedDeal: deal));
    } on Failure catch (failure) {
      emit(state.copyWith(
        status: DealsStatus.failure,
        errorMessage: failure.message,
      ));
    }
  }

  void search(String query) => emit(state.copyWith(query: query));

  /// Commits the draft in one Drift transaction. The draft is cleared only
  /// when the commit succeeded.
  Future<int?> commit(
    TransactionDraftProvider draft, {
    ItemsCacheProvider? itemsCache,
    String? updatedBy,
  }) async {
    if (!draft.canCommit) {
      emit(state.copyWith(
        errorMessage: 'Pick a client and add at least one line item.',
      ));
      return null;
    }

    emit(state.copyWith(isSaving: true, clearError: true, clearCommitted: true));
    try {
      final List<DealLineInput> lines = draft.lines;
      final int id = await _repo.commitDeal(
        clientId: draft.clientId!,
        dealType: draft.dealType,
        lines: lines,
        discount: draft.discount,
        dateTime: draft.dateTime,
        notes: draft.notes,
        commissionName: draft.commissionName,
        commissionAmount: draft.commissionAmount,
        paymentStatusOverride: draft.paymentStatusOverride,
        updatedBy: updatedBy,
      );

      _reflectSingleUse(itemsCache, lines, consumed: true);
      draft.clear();

      await loadDeals();
      emit(state.copyWith(isSaving: false, lastCommittedId: id));
      return id;
    } on ItemUnavailableFailure catch (failure) {
      emit(state.copyWith(
        isSaving: false,
        errorMessage: failure.message,
        unavailableItemLabel: failure.itemLabel,
      ));
      return null;
    } on Failure catch (failure) {
      emit(state.copyWith(isSaving: false, errorMessage: failure.message));
      return null;
    }
  }

  /// Full admin edit — allowed at any time, including after payments and
  /// refunds, because every balance is derived.
  Future<bool> editDeal(
    TransactionDraftProvider draft, {
    ItemsCacheProvider? itemsCache,
    String? updatedBy,
  }) async {
    final int? id = draft.editingTransactionId;
    if (id == null || !draft.canCommit) {
      emit(state.copyWith(errorMessage: 'This deal cannot be saved yet.'));
      return false;
    }

    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      final List<DealLineInput> lines = draft.lines;
      await _repo.editDeal(
        transactionId: id,
        clientId: draft.clientId!,
        dealType: draft.dealType,
        lines: lines,
        discount: draft.discount,
        dateTime: draft.dateTime,
        notes: draft.notes,
        commissionName: draft.commissionName,
        commissionAmount: draft.commissionAmount,
        paymentStatusOverride: draft.paymentStatusOverride,
        updatedBy: updatedBy,
      );

      _reflectSingleUse(itemsCache, lines, consumed: true);
      draft.clear();

      await loadDeals();
      await loadDeal(id);
      emit(state.copyWith(isSaving: false));
      return true;
    } on ItemUnavailableFailure catch (failure) {
      emit(state.copyWith(
        isSaving: false,
        errorMessage: failure.message,
        unavailableItemLabel: failure.itemLabel,
      ));
      return false;
    } on Failure catch (failure) {
      emit(state.copyWith(isSaving: false, errorMessage: failure.message));
      return false;
    }
  }

  /// Deletes the deal and every child row atomically, releasing single-use
  /// items back to the pool.
  Future<bool> deleteDeal(int transactionId,
      {ItemsCacheProvider? itemsCache}) async {
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      final TransactionWithItemsModel? deal =
          state.deals.where((TransactionWithItemsModel d) => d.id == transactionId).isEmpty
              ? await _repo.getDeal(transactionId)
              : state.deals
                  .firstWhere((TransactionWithItemsModel d) => d.id == transactionId);

      await _repo.deleteDeal(transactionId);

      if (deal != null && itemsCache != null) {
        for (final TransactionItemModel line in deal.items) {
          if (line.isSingleUse) {
            itemsCache.setAvailability(line.itemId, true);
          }
        }
      }

      emit(state.copyWith(
        deals: state.deals
            .where((TransactionWithItemsModel d) => d.id != transactionId)
            .toList(),
        isSaving: false,
        clearSelection: true,
        status: DealsStatus.success,
      ));
      return true;
    } on Failure catch (failure) {
      emit(state.copyWith(isSaving: false, errorMessage: failure.message));
      return false;
    }
  }

  /// Closes a car line: fixes returnKilometer and, when the line has an
  /// allowance, snapshots extraKmCharge (using [extraKmRate] entered at close
  /// time) and marks the line closed, then reloads the deal.
  Future<bool> closeCarLine({
    required int transactionId,
    required int transactionItemId,
    required double returnKilometer,
    double? extraKmRate,
  }) async {
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      await _repo.closeCarLine(
        transactionItemId: transactionItemId,
        returnKilometer: returnKilometer,
        extraKmRate: extraKmRate,
      );
      await loadDeal(transactionId);
      emit(state.copyWith(isSaving: false));
      return true;
    } on Failure catch (failure) {
      emit(state.copyWith(isSaving: false, errorMessage: failure.message));
      return false;
    }
  }

  /// Re-opens a closed car line, clearing its settlement and subtracting any
  /// snapshot extraKmCharge from the deal's totals, then reloads the deal.
  Future<bool> reopenCarLine({
    required int transactionId,
    required int transactionItemId,
  }) async {
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      await _repo.reopenCarLine(transactionItemId);
      await loadDeal(transactionId);
      emit(state.copyWith(isSaving: false));
      return true;
    } on Failure catch (failure) {
      emit(state.copyWith(isSaving: false, errorMessage: failure.message));
      return false;
    }
  }

  void _reflectSingleUse(
    ItemsCacheProvider? cache,
    List<DealLineInput> lines, {
    required bool consumed,
  }) {
    if (cache == null) return;
    for (final DealLineInput line in lines) {
      if (line.isSingleUse) {
        cache.setAvailability(line.itemId, !consumed);
      }
    }
  }

  void clearError() => emit(state.copyWith(clearError: true));
  void clearCommitted() => emit(state.copyWith(clearCommitted: true));
}
