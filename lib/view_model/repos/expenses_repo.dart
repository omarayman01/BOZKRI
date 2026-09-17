import '../../model/category_model.dart';
import '../../model/expense_model.dart';

abstract class ExpensesRepo {
  Future<List<ExpenseModel>> getExpenses({DateTime? from, DateTime? to});
  Future<double> totalInRange({DateTime? from, DateTime? to});

  Future<int> addExpense({
    required String title,
    required double amount,
    int? categoryId,
    int? transactionId,
    DateTime? dateTime,
    String? note,
  });
  Future<void> updateExpense(ExpenseModel expense);
  Future<void> deleteExpense(int id);

  Future<List<CategoryModel>> getCategories();
  Future<int> addCategory(String name);
  Future<void> deleteCategory(int id);
}
