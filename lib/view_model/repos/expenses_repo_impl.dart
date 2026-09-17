import '../../model/category_model.dart';
import '../../model/expense_model.dart';
import '../database/local/daos/expenses_dao.dart';
import '../errors/error_handler.dart';
import 'expenses_repo.dart';

class ExpensesRepoImpl implements ExpensesRepo {
  const ExpensesRepoImpl(this._dao);

  final ExpensesDao _dao;

  @override
  Future<List<ExpenseModel>> getExpenses({DateTime? from, DateTime? to}) =>
      guard(() => _dao.getInRange(from: from, to: to));

  @override
  Future<double> totalInRange({DateTime? from, DateTime? to}) =>
      guard(() => _dao.totalInRange(from: from, to: to));

  @override
  Future<int> addExpense({
    required String title,
    required double amount,
    int? categoryId,
    int? transactionId,
    DateTime? dateTime,
    String? note,
  }) =>
      guard(() => _dao.addExpense(
            title: title.trim(),
            amount: amount,
            categoryId: categoryId,
            transactionId: transactionId,
            dateTime: dateTime,
            note: note?.trim(),
          ));

  @override
  Future<void> updateExpense(ExpenseModel expense) =>
      guard(() => _dao.updateExpense(expense));

  @override
  Future<void> deleteExpense(int id) => guard(() => _dao.deleteExpense(id));

  @override
  Future<List<CategoryModel>> getCategories() => guard(_dao.getCategories);

  @override
  Future<int> addCategory(String name) =>
      guard(() => _dao.addCategory(name.trim()));

  @override
  Future<void> deleteCategory(int id) => guard(() => _dao.deleteCategory(id));
}
