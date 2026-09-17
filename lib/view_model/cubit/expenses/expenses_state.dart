import 'package:equatable/equatable.dart';

import '../../../model/category_model.dart';
import '../../../model/expense_model.dart';
import '../../../model/payment_model.dart';
import '../../utils/date_utils.dart';

enum ExpensesStatus { initial, loading, success, failure }

class ExpensesState extends Equatable {
  const ExpensesState({
    this.status = ExpensesStatus.initial,
    this.expenses = const <ExpenseModel>[],
    this.categories = const <CategoryModel>[],
    this.supplierPayments = const <PaymentModel>[],
    this.range,
    this.errorMessage,
    this.isSaving = false,
  });

  final ExpensesStatus status;
  final List<ExpenseModel> expenses;
  final List<CategoryModel> categories;

  /// Read-only cash-out visibility, never summed into [total] or any net
  /// profit figure — that cost is already counted once as COGS.
  final List<PaymentModel> supplierPayments;
  final AppDateRange? range;
  final String? errorMessage;
  final bool isSaving;

  bool get isLoading => status == ExpensesStatus.loading;
  bool get isFailure => status == ExpensesStatus.failure;
  bool get isEmpty => status == ExpensesStatus.success && expenses.isEmpty;

  double get total =>
      expenses.fold<double>(0, (double sum, ExpenseModel e) => sum + e.amount);

  double get supplierPaymentsTotal => supplierPayments.fold<double>(
      0, (double sum, PaymentModel p) => sum + p.amount);

  /// Cash-flow total, never a profit figure: expenses + supplier payments.
  double get totalCashOut => total + supplierPaymentsTotal;

  ExpensesState copyWith({
    ExpensesStatus? status,
    List<ExpenseModel>? expenses,
    List<CategoryModel>? categories,
    List<PaymentModel>? supplierPayments,
    AppDateRange? range,
    String? errorMessage,
    bool? isSaving,
    bool clearError = false,
  }) {
    return ExpensesState(
      status: status ?? this.status,
      expenses: expenses ?? this.expenses,
      categories: categories ?? this.categories,
      supplierPayments: supplierPayments ?? this.supplierPayments,
      range: range ?? this.range,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSaving: isSaving ?? this.isSaving,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        status,
        expenses,
        categories,
        supplierPayments,
        range,
        errorMessage,
        isSaving,
      ];
}
