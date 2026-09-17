import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../model/category_model.dart';
import '../../../model/expense_model.dart';
import '../../../model/payment_model.dart';
import '../../errors/failure.dart';
import '../../repos/expenses_repo.dart';
import '../../repos/payments_repo.dart';
import '../../utils/date_utils.dart';
import 'expenses_state.dart';

/// Expenses CRUD with a date-range filter, rendered on the Expenses tab.
/// Also surfaces supplier payments for the same range as a separate,
/// read-only cash-out view — never merged into the expenses total.
class ExpensesCubit extends Cubit<ExpensesState> {
  ExpensesCubit(this._repo, this._paymentsRepo) : super(const ExpensesState());

  final ExpensesRepo _repo;
  final PaymentsRepo _paymentsRepo;

  Future<void> load({AppDateRange? range}) async {
    final AppDateRange effective =
        range ?? state.range ?? AppDateUtils.currentMonth();
    emit(state.copyWith(
      status: ExpensesStatus.loading,
      range: effective,
      clearError: true,
    ));
    try {
      final List<ExpenseModel> expenses = await _repo.getExpenses(
        from: effective.start,
        to: effective.end,
      );
      final List<CategoryModel> categories = await _repo.getCategories();
      final List<PaymentModel> supplierPayments =
          await _paymentsRepo.getSupplierPayments(
        from: effective.start,
        to: effective.end,
      );
      emit(state.copyWith(
        status: ExpensesStatus.success,
        expenses: expenses,
        categories: categories,
        supplierPayments: supplierPayments,
      ));
    } on Failure catch (failure) {
      emit(state.copyWith(
        status: ExpensesStatus.failure,
        errorMessage: failure.message,
      ));
    }
  }

  Future<void> setRange(AppDateRange range) => load(range: range);

  Future<bool> addExpense({
    required String title,
    required double amount,
    int? categoryId,
    int? transactionId,
    DateTime? dateTime,
    String? note,
  }) async {
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      await _repo.addExpense(
        title: title,
        amount: amount,
        categoryId: categoryId,
        transactionId: transactionId,
        dateTime: dateTime,
        note: note,
      );
      await load();
      emit(state.copyWith(isSaving: false));
      return true;
    } on Failure catch (failure) {
      emit(state.copyWith(isSaving: false, errorMessage: failure.message));
      return false;
    }
  }

  Future<bool> updateExpense(ExpenseModel expense) async {
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      await _repo.updateExpense(expense);
      await load();
      emit(state.copyWith(isSaving: false));
      return true;
    } on Failure catch (failure) {
      emit(state.copyWith(isSaving: false, errorMessage: failure.message));
      return false;
    }
  }

  Future<bool> deleteExpense(int id) async {
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      await _repo.deleteExpense(id);
      await load();
      emit(state.copyWith(isSaving: false));
      return true;
    } on Failure catch (failure) {
      emit(state.copyWith(isSaving: false, errorMessage: failure.message));
      return false;
    }
  }

  Future<bool> addCategory(String name) async {
    try {
      await _repo.addCategory(name);
      emit(state.copyWith(categories: await _repo.getCategories()));
      return true;
    } on Failure catch (failure) {
      emit(state.copyWith(errorMessage: failure.message));
      return false;
    }
  }

  void clearError() => emit(state.copyWith(clearError: true));
}
