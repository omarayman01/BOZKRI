import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../model/payment_model.dart';
import '../../errors/failure.dart';
import '../../repos/payments_repo.dart';
import 'payments_state.dart';

/// Records client and supplier payments. Supplier payments always carry a
/// supplierId so multi-supplier deals attribute money to the right payable;
/// statuses are re-derived by reloading the deal, never stored.
class PaymentsCubit extends Cubit<PaymentsState> {
  PaymentsCubit(this._repo) : super(const PaymentsState());

  final PaymentsRepo _repo;

  Future<void> load(int transactionId) async {
    emit(state.copyWith(
      status: PaymentsStatus.loading,
      transactionId: transactionId,
      clearError: true,
    ));
    try {
      final List<PaymentModel> payments =
          await _repo.getForTransaction(transactionId);
      emit(state.copyWith(status: PaymentsStatus.success, payments: payments));
    } on Failure catch (failure) {
      emit(state.copyWith(
        status: PaymentsStatus.failure,
        errorMessage: failure.message,
      ));
    }
  }

  Future<bool> addClientPayment({
    required int transactionId,
    required double amount,
    required PaymentMethod method,
    DateTime? dateTime,
    String? notes,
  }) =>
      _add(
        transactionId: transactionId,
        party: PaymentParty.client,
        amount: amount,
        method: method,
        dateTime: dateTime,
        notes: notes,
      );

  Future<bool> addSupplierPayment({
    required int transactionId,
    required int supplierId,
    required double amount,
    required PaymentMethod method,
    DateTime? dateTime,
    String? notes,
  }) =>
      _add(
        transactionId: transactionId,
        party: PaymentParty.supplier,
        supplierId: supplierId,
        amount: amount,
        method: method,
        dateTime: dateTime,
        notes: notes,
      );

  Future<bool> _add({
    required int transactionId,
    required PaymentParty party,
    required double amount,
    required PaymentMethod method,
    int? supplierId,
    DateTime? dateTime,
    String? notes,
  }) async {
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      await _repo.addPayment(
        transactionId: transactionId,
        party: party,
        method: method,
        amount: amount,
        supplierId: supplierId,
        dateTime: dateTime,
        notes: notes,
      );
      await load(transactionId);
      emit(state.copyWith(isSaving: false));
      return true;
    } on Failure catch (failure) {
      emit(state.copyWith(isSaving: false, errorMessage: failure.message));
      return false;
    }
  }

  /// Marks one rental day paid, creating exactly one payment row for it.
  Future<bool> markRentalDayPaid({
    required int transactionId,
    required int transactionItemId,
    required DateTime rentalDayDate,
    required double amount,
    required PaymentMethod method,
    String? notes,
  }) async {
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      await _repo.markRentalDayPaid(
        transactionId: transactionId,
        transactionItemId: transactionItemId,
        rentalDayDate: rentalDayDate,
        amount: amount,
        method: method,
        notes: notes,
      );
      await load(transactionId);
      emit(state.copyWith(isSaving: false));
      return true;
    } on Failure catch (failure) {
      emit(state.copyWith(isSaving: false, errorMessage: failure.message));
      return false;
    }
  }

  Future<bool> updatePayment(PaymentModel payment) async {
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      await _repo.updatePayment(payment);
      await load(payment.transactionId);
      emit(state.copyWith(isSaving: false));
      return true;
    } on Failure catch (failure) {
      emit(state.copyWith(isSaving: false, errorMessage: failure.message));
      return false;
    }
  }

  Future<bool> deletePayment(int id, int transactionId) async {
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      await _repo.deletePayment(id);
      await load(transactionId);
      emit(state.copyWith(isSaving: false));
      return true;
    } on Failure catch (failure) {
      emit(state.copyWith(isSaving: false, errorMessage: failure.message));
      return false;
    }
  }

  /// Undo/refund one payment: marks it voided, so it stays visible in the
  /// history but stops counting toward any balance.
  Future<bool> voidPayment(int id, int transactionId) async {
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      await _repo.voidPayment(id);
      await load(transactionId);
      emit(state.copyWith(isSaving: false));
      return true;
    } on Failure catch (failure) {
      emit(state.copyWith(isSaving: false, errorMessage: failure.message));
      return false;
    }
  }

  void clearError() => emit(state.copyWith(clearError: true));
}
