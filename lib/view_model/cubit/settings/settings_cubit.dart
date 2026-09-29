import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '../../database/local/app_database.dart';
import '../../errors/error_handler.dart';
import '../../errors/failure.dart';
import '../../provider/expiry_provider.dart';
import '../../provider/settings_provider.dart';
import '../../repos/clients_repo.dart';
import '../../repos/expenses_repo.dart';
import '../../repos/item_types_repo.dart';
import '../../repos/items_repo.dart';
import '../../repos/suppliers_repo.dart';
import '../../repos/transactions_repo.dart';
import '../../sync/sync_engine.dart';
import '../../utils/db_backup_helper.dart';
import '../../utils/excel_export_helper.dart';
import '../../utils/excel_import_helper.dart';
import 'settings_state.dart';

/// Owns backup / restore file I/O. Backup writes to an admin-chosen
/// destination (folder picker or a typed/pasted path); Restore accepts
/// either a full `.sqlite` backup or a limited master-data-only `.xlsx`
/// import, branching on the chosen file's extension.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(
    this._database, {
    required TransactionsRepo transactionsRepo,
    required ItemsRepo itemsRepo,
    required ItemTypesRepo itemTypesRepo,
    required ClientsRepo clientsRepo,
    required SuppliersRepo suppliersRepo,
    required ExpensesRepo expensesRepo,
    SyncEngine? syncEngine,
  })  : _transactionsRepo = transactionsRepo,
        _itemsRepo = itemsRepo,
        _itemTypesRepo = itemTypesRepo,
        _clientsRepo = clientsRepo,
        _suppliersRepo = suppliersRepo,
        _expensesRepo = expensesRepo,
        _syncEngine = syncEngine,
        super(const SettingsState());

  final AppDatabase _database;
  final TransactionsRepo _transactionsRepo;
  final ItemsRepo _itemsRepo;
  final ItemTypesRepo _itemTypesRepo;
  final ClientsRepo _clientsRepo;
  final SuppliersRepo _suppliersRepo;
  final ExpensesRepo _expensesRepo;

  /// Null only in tests — the composition root always provides one. Used to
  /// push freshly imported master data to Supabase right away (rather than
  /// waiting for the next periodic sync) and to wipe the shared database
  /// when the admin resets the system locally.
  final SyncEngine? _syncEngine;

  /// Updates the expiry-warning window and re-flags items immediately.
  Future<void> setExpiryWarningDays(
    SettingsProvider settings,
    ExpiryProvider expiry,
    int days,
  ) async {
    await settings.setExpiryWarningDays(days);
    expiry.setWarningDays(settings.expiryWarningDays);
  }

  /// Writes only the `.xlsx` report — no `.sqlite` file, no closing the live
  /// database connection, no app restart needed afterward. A lighter-weight
  /// alternative to [backup] for admins who just want a spreadsheet copy of
  /// the current data.
  Future<void> exportExcel({String? typedPath}) async {
    String? destinationPath = typedPath?.trim();
    if (destinationPath == null || destinationPath.isEmpty) {
      destinationPath = await DbBackupHelper.pickBackupDestinationFolder();
      if (destinationPath == null) return; // cancelled, no dialog shown
    }

    emit(state.copyWith(
      status: SettingsStatus.working,
      action: SettingsAction.excelExport,
      step: SettingsStep.writingExcel,
      clearError: true,
      clearMessage: true,
    ));
    try {
      final Directory destination =
          await DbBackupHelper.resolveDestination(destinationPath);
      final String excelPath = await ExcelExportHelper.exportEndOfDayWorkbook(
        destinationFolder: destination.path,
        at: DateTime.now(),
        transactionsRepo: _transactionsRepo,
        itemsRepo: _itemsRepo,
        itemTypesRepo: _itemTypesRepo,
        clientsRepo: _clientsRepo,
        suppliersRepo: _suppliersRepo,
        expensesRepo: _expensesRepo,
      );
      emit(state.copyWith(
        status: SettingsStatus.success,
        action: SettingsAction.excelExport,
        step: SettingsStep.none,
        lastExcelPath: excelPath,
        message: 'تم الحفظ في:\n$excelPath',
        requiresRestart: false,
      ));
    } on Failure catch (failure) {
      emit(state.copyWith(
        status: SettingsStatus.failure,
        step: SettingsStep.none,
        errorMessage: failure.message,
      ));
    } catch (error) {
      emit(state.copyWith(
        status: SettingsStatus.failure,
        step: SettingsStep.none,
        errorMessage: ErrorHandler.map(error).message,
      ));
    }
  }

  /// Writes a `.sqlite` backup and a matching `.xlsx` report to
  /// [typedPath], or to a folder the admin picks via dialog when
  /// [typedPath] is null/blank. Validates the destination exists (creating
  /// it if missing) and is writable before writing anything.
  Future<void> backup({String? typedPath}) async {
    String? destinationPath = typedPath?.trim();
    if (destinationPath == null || destinationPath.isEmpty) {
      destinationPath = await DbBackupHelper.pickBackupDestinationFolder();
      if (destinationPath == null) return; // cancelled, no dialog shown
    }

    emit(state.copyWith(
      status: SettingsStatus.working,
      action: SettingsAction.backup,
      step: SettingsStep.resolvingDestination,
      clearError: true,
      clearMessage: true,
    ));
    try {
      final destination = await DbBackupHelper.resolveDestination(destinationPath);
      final DateTime at = DateTime.now();

      // Write the Excel report first, while the live connection is still
      // open — if it fails, no `.sqlite` file has been touched yet.
      emit(state.copyWith(step: SettingsStep.writingExcel));
      final String excelPath = await ExcelExportHelper.exportEndOfDayWorkbook(
        destinationFolder: destination.path,
        at: at,
        transactionsRepo: _transactionsRepo,
        itemsRepo: _itemsRepo,
        itemTypesRepo: _itemTypesRepo,
        clientsRepo: _clientsRepo,
        suppliersRepo: _suppliersRepo,
        expensesRepo: _expensesRepo,
      );

      emit(state.copyWith(step: SettingsStep.writingSqlite));
      final String sqlitePath = await DbBackupHelper.backupTo(
        database: _database,
        destination: destination,
        at: at,
      );

      emit(state.copyWith(
        status: SettingsStatus.success,
        action: SettingsAction.backup,
        step: SettingsStep.none,
        lastBackupPath: sqlitePath,
        lastExcelPath: excelPath,
        message: 'تم الحفظ في:\n$sqlitePath\n$excelPath',
        requiresRestart: true,
      ));
    } on Failure catch (failure) {
      emit(state.copyWith(
        status: SettingsStatus.failure,
        step: SettingsStep.none,
        errorMessage: failure.message,
      ));
    } catch (error) {
      emit(state.copyWith(
        status: SettingsStatus.failure,
        step: SettingsStep.none,
        errorMessage: ErrorHandler.map(error).message,
      ));
    }
  }

  /// Restores from [sourcePath] — a `.sqlite` file triggers a full,
  /// full-replace restore; an `.xlsx` file triggers a master-data-only
  /// import (clients, suppliers, items/cars). Both safety-copy or otherwise
  /// leave the live database untouched on any failure.
  Future<void> restore({required String sourcePath}) async {
    final String extension = p.extension(sourcePath).toLowerCase();
    if (extension == '.sqlite') {
      await _restoreFromSqlite(sourcePath);
    } else if (extension == '.xlsx') {
      await _restoreFromXlsx(sourcePath);
    } else {
      emit(state.copyWith(
        status: SettingsStatus.failure,
        errorMessage: 'صيغة الملف غير مدعومة — اختر ملف .sqlite أو .xlsx.',
      ));
    }
  }

  Future<void> _restoreFromSqlite(String sourcePath) async {
    emit(state.copyWith(
      status: SettingsStatus.working,
      action: SettingsAction.restore,
      step: SettingsStep.validatingBackup,
      clearError: true,
      clearMessage: true,
    ));
    try {
      emit(state.copyWith(step: SettingsStep.replacingDatabase));
      await DbBackupHelper.restoreFromSqlite(
        database: _database,
        sourcePath: sourcePath,
      );

      emit(state.copyWith(
        status: SettingsStatus.success,
        action: SettingsAction.restore,
        step: SettingsStep.none,
        lastRestoredFromPath: sourcePath,
        message: 'تمت استعادة قاعدة البيانات من: ${p.basename(sourcePath)}',
        requiresRestart: true,
      ));
    } on Failure catch (failure) {
      emit(state.copyWith(
        status: SettingsStatus.failure,
        step: SettingsStep.none,
        errorMessage: failure.message,
      ));
    } catch (error) {
      emit(state.copyWith(
        status: SettingsStatus.failure,
        step: SettingsStep.none,
        errorMessage: ErrorHandler.map(error).message,
      ));
    }
  }

  Future<void> _restoreFromXlsx(String sourcePath) async {
    emit(state.copyWith(
      status: SettingsStatus.working,
      action: SettingsAction.restore,
      step: SettingsStep.importingMasterData,
      clearError: true,
      clearMessage: true,
    ));
    try {
      final MasterDataImportSummary summary =
          await ExcelImportHelper.importMasterData(
        sourcePath: sourcePath,
        clientsRepo: _clientsRepo,
        suppliersRepo: _suppliersRepo,
        itemsRepo: _itemsRepo,
        itemTypesRepo: _itemTypesRepo,
      );

      // Push the freshly imported rows to Supabase right away rather than
      // waiting for the next periodic sync — best-effort: an offline or
      // failed push here just leaves them queued for the normal sync cycle.
      unawaited(_syncEngine?.syncAll());

      final String summaryText = 'تم استيراد بيانات أساسية من '
          '${p.basename(sourcePath)}: ${summary.totalCreated} عنصر جديد، '
          '${summary.totalUpdated} عنصر محدث (عملاء/موردين/أنواع أصناف '
          'وحقولها/سيارات فقط — لم يتم استيراد صفقات أو دفعات أو أرصدة). '
          'جارٍ رفعها إلى قاعدة البيانات المشتركة الآن.';

      emit(state.copyWith(
        status: SettingsStatus.success,
        action: SettingsAction.restore,
        step: SettingsStep.none,
        lastRestoredFromPath: sourcePath,
        lastImportSummary: summaryText,
        message: summaryText,
        requiresRestart: false,
      ));
    } on Failure catch (failure) {
      emit(state.copyWith(
        status: SettingsStatus.failure,
        step: SettingsStep.none,
        errorMessage: failure.message,
      ));
    } catch (error) {
      emit(state.copyWith(
        status: SettingsStatus.failure,
        step: SettingsStep.none,
        errorMessage: ErrorHandler.map(error).message,
      ));
    }
  }

  /// Wipes every client, supplier, item, deal, payment, refund, and expense
  /// — keeping item types/fields and expense categories intact. Runs over
  /// the same open connection, so unlike backup/restore, no app restart is
  /// needed afterward; the caller (the reset tile) is responsible for
  /// reloading every cache/cubit once this returns `true`.
  Future<bool> resetSystem() async {
    emit(state.copyWith(
      status: SettingsStatus.working,
      action: SettingsAction.reset,
      step: SettingsStep.wiping,
      clearError: true,
      clearMessage: true,
    ));
    try {
      await _database.resetAllData();

      String message = 'تم إعادة تعيين النظام.';
      if (_syncEngine != null) {
        try {
          await _syncEngine.wipeRemoteData();
          message = 'تم إعادة تعيين النظام محلياً وعلى قاعدة البيانات '
              'المشتركة (Supabase).';
        } catch (_) {
          message = 'تم إعادة تعيين النظام محلياً، لكن تعذر مسح البيانات من '
              'قاعدة البيانات المشتركة (تحقق من الاتصال بالإنترنت) — اضغط '
              'إعادة تعيين النظام مرة أخرى لإكمال المسح على القاعدة '
              'المشتركة.';
        }
      }

      emit(state.copyWith(
        status: SettingsStatus.success,
        action: SettingsAction.reset,
        step: SettingsStep.none,
        message: message,
        requiresRestart: false,
      ));
      return true;
    } on Failure catch (failure) {
      emit(state.copyWith(
        status: SettingsStatus.failure,
        step: SettingsStep.none,
        errorMessage: failure.message,
      ));
      return false;
    } catch (error) {
      emit(state.copyWith(
        status: SettingsStatus.failure,
        step: SettingsStep.none,
        errorMessage: ErrorHandler.map(error).message,
      ));
      return false;
    }
  }

  void clearError() => emit(state.copyWith(clearError: true));
  void clearMessage() => emit(state.copyWith(clearMessage: true));
}
