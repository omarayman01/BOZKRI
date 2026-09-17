# Phase 11 — Backup & Restore: Two-Button Settings (supersedes Phase 6)

[← Back to roadmap index](../FEATURES_ROADMAP.md)

## Goal
Replace Phase 6's fixed-Desktop/fixed-folder, mostly picker-free backup design with a simpler
two-button Settings surface: one button backs up to an admin-chosen destination (folder picker
*or* a typed/pasted absolute path), the other restores from an admin-chosen file, accepting
either a full `.sqlite` backup or a limited master-data-only `.xlsx` import.

## Depends on
Phases 1–5 (Arabic dialog/file-naming text; Excel column set already includes the Phase 3–5
fields). Directly supersedes Phase 6 — Phase 6's fixed-path, no-picker design is replaced
outright, not layered on top of.

## Schema deltas
None. This phase is file-system I/O and its surrounding cubit/UI, like Phase 6 was.

## State
- `cubit/settings/settings_cubit.dart` (or a renamed `cubit/backup/backup_cubit.dart` — the role
  Phase 6 already assigned it is unchanged, only its two actions' internals change):
  - `Future<void> backup({String? typedPath})` — if `typedPath` is null, opens a folder picker;
    otherwise validates the typed/pasted path. Either way: validate the destination exists and
    is writable (offer to create it if missing), then write both files there.
  - `Future<void> restore()` — opens a file picker accepting `.sqlite` or `.xlsx`; branches
    internally on the chosen file's extension (see DAO/repo below).
- `cubit/settings/settings_state.dart` — `SettingsStep` gains steps for the two new sub-flows:
  `resolvingDestination`, `writingSqlite`, `writingExcel` (backup, in that order) and
  `validatingBackup`, `importingMasterData`, `replacingDatabase` (restore, branch-dependent).
  `SettingsAction` narrows back to just `backup` / `restore` (the separate `backupNow` /
  `restoreLatest` / `copyToExternal` / `endOfDaySave` actions Phase 6 introduced are retired).

## DAO / repo
- `utils/db_backup_helper.dart`:
  - `Future<Directory> resolveDestination({String? typedPath})` — folder-picker result or the
    typed path, `Directory.createSync(recursive: true)` if missing and the admin confirms;
    throws a clear Arabic `FileFailure` if the path exists but is not writable.
  - `Future<String> backupTo({required AppDatabase database, required Directory destination,
    required DateTime at})` — checkpoint + close + copy to
    `destination/bozkri_YYYY-MM-DD_HHmm.sqlite`; reopens the connection after.
  - `Future<void> restoreFromSqlite({required AppDatabase database, required String
    sourcePath})` — validates schema/version via `AppDatabase.isValidBackup`, safety-copies the
    current DB first (timestamped, as Phase 6 already established), full-replaces, reopens.
    Throws if the file fails validation; the live DB is never touched until validation passes.
- `utils/excel_export_helper.dart` — reused unchanged from Phase 6 (column layout, per-item-type
  sheets, per-supplier sheets); only its destination folder is now whatever `resolveDestination`
  returned instead of the fixed Desktop path.
- `utils/excel_import_helper.dart` (new) — `Future<MasterDataImportSummary>
  importMasterData({required String sourcePath, required ClientsRepo clientsRepo, required
  SuppliersRepo suppliersRepo, required ItemsRepo itemsRepo})`: reads the Clients, Suppliers,
  and Items/Cars sheets of the chosen `.xlsx`, upserts each row by its natural key (client
  name+phone, supplier name+phone, item label+supplier — same matching the admin already uses
  when searching), and returns counts (created/updated per table) for the success message. Does
  **not** touch `transactions`, `transaction_items`, `payments`, `refunds`, or `expenses` — an
  Excel file cannot carry the relational + snapshot integrity those tables require, so deals,
  payments, and balances are left exactly as they were before the import.
- `utils/backup_validator.dart` — `AppDatabase.isValidBackup` reused unchanged from Phase 6 for
  the `.sqlite` branch; no equivalent validation needed for `.xlsx` beyond "sheet exists."

## UI
- `view/features/settings_features/settings_screen.dart` — the backup/restore section is
  reduced to exactly two tiles:
  - `widgets/backup_tile.dart` ("حفظ نسخة احتياطية") — one primary button; on press, offers a
    folder-picker button and a text field to paste/type an absolute path (either satisfies the
    action — picking a folder fills the text field, typing skips the picker). Confirms, then
    shows the blocking overlay through resolve → write `.sqlite` → write `.xlsx` → reopen, then
    a success message with both full file paths (unlike Phase 6, full paths are shown here since
    the destination is no longer a fixed, always-known location).
  - `widgets/restore_tile.dart` ("استرجاع البيانات") — one destructive-styled button; opens a
    file picker for `.sqlite` or `.xlsx`. Branches on extension:
    - `.sqlite` chosen → the full-restore confirmation dialog (current data replaced; a safety
      copy is kept; app restart required after), same warning shape Phase 6 already used.
    - `.xlsx` chosen → a distinct confirmation dialog stating plainly, in Arabic, that this
      import brings back **only** clients, suppliers, and cars/items — **not** deals, payments,
      refunds, or balances — before proceeding; requires an explicit confirm click, not just the
      file selection, to proceed.
  - The four separate tiles Phase 6 introduced (`end_of_day_save_tile.dart`,
    `backup_now_tile.dart`, `restore_latest_tile.dart`, `copy_to_external_tile.dart`) are
    deleted; Settings shows only `backup_tile.dart` and `restore_tile.dart` for data.
- `view/core/widgets/blocking_progress_overlay.dart` — reused unchanged, wrapping every step of
  both flows with the Arabic per-step status line described in State above.

## Localization
New/changed labels: حفظ نسخة احتياطية, استرجاع البيانات, اختر مجلداً أو أدخل مساراً, المجلد غير
قابل للكتابة, تم الحفظ في, استرجاع كامل (.sqlite), استرجاع بيانات أساسية فقط (.xlsx), هذا
الاستيراد يجلب فقط العملاء والموردين والسيارات — لا يجلب الصفقات أو الدفعات أو الأرصدة. All
dialog/success/failure text in Arabic per Phase 1's global rule; file paths themselves stay
LTR-embedded like every other Latin-script token.

## Acceptance criteria
- [ ] Choosing a destination folder via the picker and typing/pasting an absolute path both
      work identically for Backup; a nonexistent path offers to create it, and a
      non-writable path is rejected with a clear Arabic message before any write is attempted.
- [ ] A single Backup run writes exactly two timestamped files
      (`bozkri_YYYY-MM-DD_HHmm.sqlite` / `.xlsx`) to the resolved destination and reports success
      only when both are confirmed written, with both full paths shown.
- [ ] Restoring from a `.sqlite` file fully rebuilds the app's state on a clean machine —
      deals, payments, refunds, balances, everything — after validating the file's schema first
      and safety-copying the current database before replacing it.
- [ ] Restoring from an `.xlsx` file upserts only clients, suppliers, and cars/items; it never
      creates, deletes, or modifies any `transactions`/`transaction_items`/`payments`/
      `refunds`/`expenses` row; the admin sees and must confirm the Arabic disclaimer before the
      import runs.
- [ ] A failed restore (bad file, validation failure, disk error mid-copy) leaves the live
      database exactly as it was — the safety copy is made before any destructive step, and any
      exception aborts before the live file is touched.
- [ ] Settings shows exactly two buttons for backup/restore — no separate end-of-day, routine
      backup, restore-latest, or external-copy tiles remain.
- [ ] Every step of both flows (resolving the destination, writing each file, validating,
      importing, replacing) shows the blocking progress overlay with an Arabic status line, then
      a clear Arabic success or failure result.

## Out of scope
- Partial/selective restore from a `.sqlite` file (still strictly full-replace).
- Merging or reconciling conflicting rows during an `.xlsx` master-data import — later rows for
  the same natural key simply overwrite earlier ones in the same import pass, same as any other
  upsert in this app.
- Importing deals/payments/refunds/expenses from Excel in any form.
