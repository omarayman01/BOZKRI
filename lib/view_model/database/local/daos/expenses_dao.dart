import 'package:drift/drift.dart';

import '../../../../model/category_model.dart';
import '../../../../model/expense_model.dart';
import '../../../errors/db_failure.dart';
import '../app_database.dart';
import '../mappers.dart';
import '../tables.dart';

part 'expenses_dao.g.dart';

@DriftAccessor(tables: <Type>[Expenses, ExpenseCategories, Transactions])
class ExpensesDao extends DatabaseAccessor<AppDatabase>
    with _$ExpensesDaoMixin {
  ExpensesDao(super.db);

  Future<List<ExpenseModel>> getInRange({DateTime? from, DateTime? to}) async {
    final StringBuffer where = StringBuffer();
    final List<Variable<Object>> vars = <Variable<Object>>[];
    if (from != null) {
      where.write(' AND e.date_time >= ?');
      vars.add(Variable<DateTime>(from));
    }
    if (to != null) {
      where.write(' AND e.date_time <= ?');
      vars.add(Variable<DateTime>(to));
    }

    final List<QueryRow> rows = await customSelect(
      '''
      SELECT e.*, ec.name AS category_name
      FROM expenses e
      LEFT JOIN expense_categories ec ON ec.id = e.category_id
      WHERE 1 = 1${where.toString()}
      ORDER BY e.date_time DESC
      ''',
      variables: vars,
      readsFrom: <ResultSetImplementation<HasResultSet, Object>>{
        expenses,
        expenseCategories,
      },
    ).get();

    return rows
        .map((QueryRow r) => expenses
            .map(r.data, tablePrefix: null)
            .toModel(categoryName: r.read<String?>('category_name')))
        .toList();
  }

  Future<double> totalInRange({DateTime? from, DateTime? to}) async {
    final StringBuffer where = StringBuffer();
    final List<Variable<Object>> vars = <Variable<Object>>[];
    if (from != null) {
      where.write(' AND date_time >= ?');
      vars.add(Variable<DateTime>(from));
    }
    if (to != null) {
      where.write(' AND date_time <= ?');
      vars.add(Variable<DateTime>(to));
    }
    final QueryRow row = await customSelect(
      'SELECT COALESCE(SUM(amount), 0) AS s FROM expenses '
      'WHERE 1 = 1${where.toString()}',
      variables: vars,
      readsFrom: <ResultSetImplementation<HasResultSet, Object>>{expenses},
    ).getSingle();
    return row.read<double>('s');
  }

  Future<int> addExpense({
    required String title,
    required double amount,
    int? categoryId,
    int? transactionId,
    DateTime? dateTime,
    String? note,
  }) {
    if (amount <= 0) {
      throw const ConstraintFailure('Expense amount must be greater than zero.');
    }
    return into(expenses).insert(
      ExpensesCompanion.insert(
        title: title,
        amount: amount,
        categoryId: Value<int?>(categoryId),
        transactionId: Value<int?>(transactionId),
        occurredAt: dateTime ?? DateTime.now(),
        note: Value<String?>(note),
      ),
    );
  }

  Future<int> updateExpense(ExpenseModel expense) {
    if (expense.amount <= 0) {
      throw const ConstraintFailure('Expense amount must be greater than zero.');
    }
    return (update(expenses)..where(($ExpensesTable t) => t.id.equals(expense.id)))
        .write(
      ExpensesCompanion(
        title: Value<String>(expense.title),
        amount: Value<double>(expense.amount),
        categoryId: Value<int?>(expense.categoryId),
        transactionId: Value<int?>(expense.transactionId),
        occurredAt: Value<DateTime>(expense.dateTime),
        note: Value<String?>(expense.note),
        updatedAt: Value<DateTime>(DateTime.now()),
      ),
    );
  }

  Future<int> deleteExpense(int id) =>
      (delete(expenses)..where(($ExpensesTable t) => t.id.equals(id))).go();

  // ---- Categories ----

  Future<List<CategoryModel>> getCategories() async {
    final List<ExpenseCategoryRow> rows = await (select(expenseCategories)
          ..orderBy(<OrderClauseGenerator<$ExpenseCategoriesTable>>[
            (($ExpenseCategoriesTable t) => OrderingTerm.asc(t.name)),
          ]))
        .get();
    return rows.map((ExpenseCategoryRow r) => r.toModel()).toList();
  }

  Future<int> addCategory(String name) => into(expenseCategories)
      .insert(ExpenseCategoriesCompanion.insert(name: name));

  Future<int> deleteCategory(int id) => (delete(expenseCategories)
        ..where(($ExpenseCategoriesTable t) => t.id.equals(id)))
      .go();
}
