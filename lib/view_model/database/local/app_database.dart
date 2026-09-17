import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../view/constants/app_constants.dart';
import 'daos/clients_dao.dart';
import 'daos/dashboard_dao.dart';
import 'daos/expenses_dao.dart';
import 'daos/item_types_dao.dart';
import 'daos/items_dao.dart';
import 'daos/payments_dao.dart';
import 'daos/refunds_dao.dart';
import 'daos/suppliers_dao.dart';
import 'daos/transactions_dao.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: <Type>[
    Suppliers,
    Clients,
    ItemTypes,
    ItemTypeFields,
    Items,
    ItemFieldValues,
    Transactions,
    TransactionItems,
    Payments,
    Refunds,
    RefundItems,
    ExpenseCategories,
    Expenses,
  ],
  daos: <Type>[
    ClientsDao,
    SuppliersDao,
    ItemTypesDao,
    ItemsDao,
    TransactionsDao,
    PaymentsDao,
    RefundsDao,
    ExpensesDao,
    DashboardDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Opens the on-disk database in the application support directory.
  ///
  /// Must be awaited before `runApp` (see `startApp()` in app.dart).
  static Future<AppDatabase> open() async {
    final File file = await databaseFile();
    return AppDatabase(NativeDatabase(file, logStatements: false));
  }

  static Future<File> databaseFile() async {
    final Directory dir = await getApplicationSupportDirectory();
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return File(p.join(dir.path, AppConstants.dbFileName));
  }

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _seedExpenseCategories();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await m.addColumn(clients, clients.passportId);
            await m.addColumn(clients, clients.nationalId);
          }
          if (from < 3) {
            await m.addColumn(transactionItems, transactionItems.pricePerDay);
            await m.addColumn(transactionItems, transactionItems.costPerDay);
            await m.addColumn(transactionItems, transactionItems.days);
            await m.addColumn(payments, payments.transactionItemId);
            await m.addColumn(payments, payments.rentalDayDate);
          }
          if (from < 4) {
            await m.addColumn(transactionItems, transactionItems.allowedKmPerDay);
            await m.addColumn(transactionItems, transactionItems.extraKmRate);
            await m.addColumn(transactionItems, transactionItems.pickupKilometer);
            await m.addColumn(transactionItems, transactionItems.returnKilometer);
            await m.addColumn(transactionItems, transactionItems.extraKmCharge);
            await m.addColumn(transactionItems, transactionItems.lineStatus);
          }
          if (from < 5) {
            await m.addColumn(transactions, transactions.commissionName);
            await m.addColumn(transactions, transactions.commissionAmount);
            await m.addColumn(transactions, transactions.paymentStatusOverride);
          }
          if (from < 6) {
            await m.addColumn(payments, payments.voided);
          }
          if (from < 7) {
            await _translateExpenseCategoryDefaults();
          }
        },
        beforeOpen: (OpeningDetails details) async {
          // SQLite ignores foreign keys unless explicitly enabled per
          // connection. Every ON DELETE CASCADE in tables.dart depends on it.
          await customStatement('PRAGMA foreign_keys = ON');
          await customStatement('PRAGMA journal_mode = WAL');
          await _createIndexes();
        },
      );

  Future<void> _createIndexes() async {
    const List<String> statements = <String>[
      'CREATE INDEX IF NOT EXISTS idx_items_supplier ON items (supplier_id)',
      'CREATE INDEX IF NOT EXISTS idx_items_type ON items (item_type_id)',
      'CREATE INDEX IF NOT EXISTS idx_ifv_item ON item_field_values (item_id)',
      'CREATE INDEX IF NOT EXISTS idx_tx_client ON transactions (client_id)',
      'CREATE INDEX IF NOT EXISTS idx_tx_date ON transactions (date_time)',
      'CREATE INDEX IF NOT EXISTS idx_ti_tx ON transaction_items (transaction_id)',
      'CREATE INDEX IF NOT EXISTS idx_ti_supplier ON transaction_items (supplier_id)',
      'CREATE INDEX IF NOT EXISTS idx_ti_item ON transaction_items (item_id)',
      'CREATE INDEX IF NOT EXISTS idx_pay_tx ON payments (transaction_id)',
      'CREATE INDEX IF NOT EXISTS idx_pay_supplier ON payments (supplier_id)',
      'CREATE INDEX IF NOT EXISTS idx_ref_tx ON refunds (transaction_id)',
      'CREATE INDEX IF NOT EXISTS idx_ri_refund ON refund_items (refund_id)',
      'CREATE INDEX IF NOT EXISTS idx_ri_ti ON refund_items (transaction_item_id)',
      'CREATE INDEX IF NOT EXISTS idx_exp_date ON expenses (date_time)',
    ];
    for (final String sql in statements) {
      await customStatement(sql);
    }
  }

  Future<void> _seedExpenseCategories() async {
    await batch((Batch b) {
      b.insertAll(
        expenseCategories,
        _defaultExpenseCategoryTranslations.values
            .map((String name) => ExpenseCategoriesCompanion.insert(name: name))
            .toList(),
      );
    });
  }

  /// Old English default -> Arabic default, used both to seed a fresh
  /// install and to relabel an existing install's still-unrenamed defaults
  /// in place (schema v7). An admin-renamed or admin-added category is
  /// never matched here, since matching is by exact string identity with
  /// what the app itself used to seed.
  static const Map<String, String> _defaultExpenseCategoryTranslations = {
    'Rent': 'إيجار',
    'Salaries': 'رواتب',
    'Utilities': 'مرافق',
    'Marketing': 'تسويق',
    'Transport': 'مواصلات',
    'Other': 'أخرى',
  };

  Future<void> _translateExpenseCategoryDefaults() async {
    for (final MapEntry<String, String> entry
        in _defaultExpenseCategoryTranslations.entries) {
      await (update(expenseCategories)
            ..where(($ExpenseCategoriesTable t) => t.name.equals(entry.key)))
          .write(ExpenseCategoriesCompanion(name: Value<String>(entry.value)));
    }
  }

  /// Wipes every client, supplier, item, deal, payment, refund, and expense
  /// — but keeps item types/fields and expense categories intact, so the
  /// app isn't left completely unconfigured. Runs over the same open
  /// connection (unlike backup/restore, no restart is needed afterward).
  ///
  /// Deletion order matters: `items`/`transactions` must go before the
  /// `suppliers`/`clients` they reference, since those foreign keys are
  /// plain `.references(...)` (NO ACTION, not cascading) and
  /// `PRAGMA foreign_keys = ON` is set for every connection.
  Future<void> resetAllData() {
    return transaction(() async {
      // Cascades: transaction_items, payments, refunds -> refund_items, and
      // any commission-linked expense (transaction_id set).
      await delete(transactions).go();
      // Remaining, non-transaction-linked expenses.
      await delete(expenses).go();
      // Cascades: item_field_values.
      await delete(items).go();
      await delete(suppliers).go();
      await delete(clients).go();
    });
  }

  /// Flushes the write-ahead log into the main database file and closes the
  /// connection, so the file on disk can be safely copied for a backup.
  Future<void> checkpointAndClose() async {
    // A checkpoint can transiently fail (SQLITE_BUSY) if a reader hasn't
    // yet released its snapshot — most commonly seen on Windows, where
    // handle teardown from a just-finished query can lag by a tick.
    for (int attempt = 1; ; attempt++) {
      try {
        await customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
        break;
      } on SqliteException {
        if (attempt >= 5) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
    }
    await close();
  }

  /// Verifies that a candidate restore file is a readable SQLite database
  /// containing this schema. Runs on a throwaway connection.
  static bool isValidBackup(File candidate) {
    if (!candidate.existsSync()) return false;
    Database? db;
    try {
      db = sqlite3.open(candidate.path, mode: OpenMode.readOnly);
      final ResultSet rows = db.select(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
        <Object?>['transactions'],
      );
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    } finally {
      db?.dispose();
    }
  }
}
