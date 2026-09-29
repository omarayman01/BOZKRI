import 'package:equatable/equatable.dart';

enum SettingsStatus { initial, working, success, failure }

/// Which file operation produced the current state, so the UI can show the
/// right confirmation message.
enum SettingsAction { none, backup, restore, reset, excelExport }

/// Which step of a multi-step action is currently running, so the blocking
/// overlay can show a specific status line instead of a generic spinner.
enum SettingsStep {
  none,
  resolvingDestination,
  writingSqlite,
  writingExcel,
  validatingBackup,
  importingMasterData,
  replacingDatabase,
  wiping,
}

class SettingsState extends Equatable {
  const SettingsState({
    this.status = SettingsStatus.initial,
    this.action = SettingsAction.none,
    this.lastBackupPath,
    this.lastExcelPath,
    this.lastRestoredFromPath,
    this.lastImportSummary,
    this.step = SettingsStep.none,
    this.message,
    this.errorMessage,
    this.requiresRestart = false,
  });

  final SettingsStatus status;
  final SettingsAction action;

  /// Full path of the `.sqlite` file written by the last Backup.
  final String? lastBackupPath;

  /// Full path of the `.xlsx` file written by the last Backup.
  final String? lastExcelPath;

  /// Path the last restore was sourced from.
  final String? lastRestoredFromPath;

  /// Set only after an `.xlsx` (master-data-only) restore — a short summary
  /// string for the success message (created/updated counts per table).
  final String? lastImportSummary;
  final SettingsStep step;
  final String? message;
  final String? errorMessage;

  /// True after a `.sqlite` restore: the database connection was replaced
  /// on disk and the app must be relaunched to read it. An `.xlsx` import
  /// does not set this — the live connection stays open throughout.
  final bool requiresRestart;

  bool get isWorking => status == SettingsStatus.working;
  bool get isFailure => status == SettingsStatus.failure;

  SettingsState copyWith({
    SettingsStatus? status,
    SettingsAction? action,
    String? lastBackupPath,
    String? lastExcelPath,
    String? lastRestoredFromPath,
    String? lastImportSummary,
    SettingsStep? step,
    String? message,
    String? errorMessage,
    bool? requiresRestart,
    bool clearError = false,
    bool clearMessage = false,
  }) {
    return SettingsState(
      status: status ?? this.status,
      action: action ?? this.action,
      lastBackupPath: lastBackupPath ?? this.lastBackupPath,
      lastExcelPath: lastExcelPath ?? this.lastExcelPath,
      lastRestoredFromPath: lastRestoredFromPath ?? this.lastRestoredFromPath,
      lastImportSummary: lastImportSummary ?? this.lastImportSummary,
      step: step ?? this.step,
      message: clearMessage ? null : (message ?? this.message),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      requiresRestart: requiresRestart ?? this.requiresRestart,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        status,
        action,
        lastBackupPath,
        lastExcelPath,
        lastRestoredFromPath,
        lastImportSummary,
        step,
        message,
        errorMessage,
        requiresRestart,
      ];
}
