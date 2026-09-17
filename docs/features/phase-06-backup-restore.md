# Phase 6 — End-of-Day Save, Backup, Restore (fixed Desktop path, no pickers) — ✅ Done

[← Back to roadmap index](../FEATURES_ROADMAP.md)

## Goal
Replace every file-picker-driven backup/restore flow with fixed, automatic locations so a
non-technical admin never has to navigate a save/open dialog for routine backups — while
keeping exactly one deliberate, picker-driven action for copying a backup off the machine.

## Depends on
Phases 1–5 (Arabic dialog/file-naming text; final Excel column set needs the Phase 3–5 fields).

## Schema deltas
None. This phase is file-system I/O and its surrounding cubit/UI, like the prior revision's
Phase 1, but with fixed destinations replacing every file-picker call.

## State
- `cubit/backup/backup_cubit.dart` (new) — three primary actions plus the one picker-based one:
  - `Future<void> saveEndOfDay()` — writes both files to the Desktop.
  - `Future<void> backupNow()` — writes a `.sqlite` snapshot to the fixed app-managed backups
    folder.
  - `Future<void> restoreLatest()` — restores from the most recent file in that folder.
  - `Future<void> copyLatestBackupToExternalDrive()` — the one action that opens a folder
    picker, to choose the external drive/destination.
- `cubit/backup/backup_state.dart` (new) — status/step/message shape equivalent to the prior
  revision's `SettingsState` (`working` / per-step label / `success` / `failure`), extended with
  a `lastBackupFolderPath` and `lastDesktopSavePaths` (both file names) for the success message.

## DAO / repo
No DB queries beyond what Phase 6 of the prior revision already established for reading every
table into the Excel export (`TransactionsRepo.getDeals`, `ItemsRepo.getItems`,
`ItemTypesRepo.getTypes`, `ClientsRepo.getClients`, `SuppliersRepo.getSuppliers`,
`ExpensesRepo.getExpenses`). New utility surface (no DB access):

- `utils/desktop_path_util.dart` — resolves the OS Desktop folder automatically (via
  `path_provider`'s platform folder resolution or the platform's known-folder API), and the
  fixed app-managed backups folder (e.g. under the same application-support directory the
  database itself lives in) — no path is ever chosen by the admin for these two.
- `utils/db_backup_helper.dart` — extended with:
  - `Future<String> saveToDesktop({required AppDatabase database, required DateTime at})` —
    checkpoint + close + copy to the resolved Desktop path, filename
    `bozkri_YYYY-MM-DD_HHmm.sqlite`.
  - `Future<String> backupToFixedFolder({required AppDatabase database, required DateTime at})`
    — same copy, into the fixed backups folder instead of the Desktop.
  - `Future<String?> findLatestBackup()` — newest `.sqlite` in the fixed backups folder, or
    `null` if none exists yet.
  - `Future<void> restoreFromLatest({required AppDatabase database})` — auto safety-copies the
    current DB, validates the latest backup found by `findLatestBackup()`, full-replaces, no
    picker at any step. Throws a clear, distinct error when no backup exists yet.
  - `Future<String> copyToExternalDrive({required String destinationFolder})` — the one
    picker-driven action; copies the file `findLatestBackup()` returns.
- `utils/excel_export_helper.dart` — reused from the prior revision's Phase 6 design (category
  detection per item type, apartments/flights/cars column sets, per-supplier sheets), pointed at
  the Desktop as its destination folder for End-of-Day Save instead of an admin-chosen folder.
- `utils/backup_validator.dart` (new, or the existing `AppDatabase.isValidBackup` reused as-is)
  — schema/version and core-table sanity check run before any restore.

## UI
- `view/features/settings_features/widgets/end_of_day_save_tile.dart` — one dominant button
  ("حفظ نهاية اليوم") triggering `saveEndOfDay()`; on success, shows both written file names
  (not full paths, since the location is fixed and known) under a blocking-overlay-then-message
  flow.
- `view/features/settings_features/widgets/backup_now_tile.dart` (new) — a secondary button
  ("نسخة احتياطية الآن") triggering `backupNow()`; reports the saved file name on success.
- `view/features/settings_features/widgets/restore_latest_tile.dart` (new) — a secondary,
  destructive-styled button ("استعادة آخر نسخة") triggering `restoreLatest()`, gated behind a
  confirmation dialog naming what will happen (current data replaced; a safety copy is kept).
- `view/features/settings_features/widgets/copy_to_external_tile.dart` (new) — the one tile that
  opens a folder picker ("نسخ إلى محرك خارجي"), explained in a one-line caption as the
  recommended way to protect against a single-disk failure.
- `view/core/widgets/blocking_progress_overlay.dart` (already exists from the prior revision) —
  reused, wrapping the whole Settings screen body during any of the four operations above, with
  an Arabic status line per step (كتابة قاعدة البيانات… / كتابة تقرير الإكسل… / التحقق من
  النسخة… / الاستبدال…).

## Localization
New/changed labels: حفظ نهاية اليوم, نسخة احتياطية الآن, استعادة آخر نسخة,
نسخ إلى محرك خارجي, تم الحفظ في: (سطح المكتب), تم إنشاء نسخة احتياطية, تم استعادة قاعدة
البيانات — أعد تشغيل التطبيق, لا توجد نسخة احتياطية بعد, اختر مجلد النسخ الخارجي. All dialog
and success/failure text in Arabic per Phase 1's global rule. No RTL-specific layout beyond
standard text flow; file names themselves stay LTR-embedded like any other Latin-script token
(dates/times inside the name) per the existing digit convention.

## Acceptance criteria
- [x] "حفظ نهاية اليوم" writes exactly two new files directly to the OS Desktop with no file
      dialog and no browser-style download prompt of any kind:
      `bozkri_YYYY-MM-DD_HHmm.sqlite` and the matching `.xlsx`.
- [x] End-of-Day Save reports success only when **both** files are confirmed written; the Excel
      file is written first while the connection is still open, so if it fails no `.sqlite` file
      has been touched yet.
- [x] "نسخة احتياطية الآن" writes a `.sqlite` snapshot into the fixed app-managed backups
      folder automatically, with no dialog, and reports the saved file name.
- [x] "استعادة آخر نسخة" restores from the newest file in that fixed folder automatically, with
      no file picker at any point; it always creates a timestamped safety copy of the *current*
      database first (`<db>.pre-restore-<stamp>`, so repeated restores never clobber an earlier
      one); restoring is strictly full-replace (no merge); it is rejected cleanly with a clear
      Arabic message ("لا توجد نسخة احتياطية بعد.") when the fixed folder has no backup yet.
- [x] Attempting to restore from an `.xlsx` file is impossible by construction — there is no
      code path that accepts one, since restore always sources from `findLatestBackup()`, which
      only lists `.sqlite` files.
- [x] "نسخ إلى محرك خارجي" is the only action in the entire backup/restore/export surface that
      opens a system file/folder picker (`DbBackupHelper.pickExternalDestinationFolder`).
- [x] Every one of the four actions shows the blocking progress overlay (driven by
      `SettingsState.step`) from the moment it starts until it completes, then a clear Arabic
      success or failure message; no action touching disk ever returns silently.
- [x] The exported `.xlsx` mirrors the agency's real column layout for Apartments, Flights,
      Cars (including the Phase 3–5 fields: المده باليوم, السعر اليوم, الاجمالي,
      صافي الربح باليوم, اجمالي صافي الربح, العمولة, حالة العقد) plus one sheet per supplier
      with نوع السيارة / الطرقات / المده / من تاريخ / الي تاريخ / عدد الكيلومترات / القيمة /
      ملاحظات / حالة الدفع — reused unchanged from `excel_export_helper.dart` (prior revision's
      Phase 6 work); this phase only changed where the file is written, not its contents.
- [ ] A backup produced by either "حفظ نهاية اليوم" or "نسخة احتياطية الآن" is verified
      restorable on a clean second machine — **manual verification pass, not part of this code
      change**; run it once before relying on backups in production.

Implemented in `utils/desktop_path_util.dart` (new — resolves the Desktop and the fixed
app-managed backups folder, no picker), `utils/db_backup_helper.dart` (rewritten:
`saveToDesktop`/`backupToFixedFolder`/`findLatestBackup`/`restoreFromLatest`/
`copyToExternalDrive`, replacing the old picker-driven flow), `cubit/settings/settings_cubit.dart`
+ `settings_state.dart` (four actions — `backupNow`/`restoreLatest`/
`copyLatestBackupToExternalDrive`/`saveEndOfDay` — replacing `backup`/`restore`), and four
Settings tiles: `end_of_day_save_tile.dart` (rewritten), `backup_now_tile.dart`,
`restore_latest_tile.dart`, `copy_to_external_tile.dart` (new — these three replace the deleted
picker-based `backup_restore_tile.dart`). Removed the now-unused admin-chosen-directory
preference (`SettingsProvider.backupDirectory`, `prefsBackupDirKey`) since destinations are
fixed. `excel_export_helper.dart`'s column layout and `AppDatabase.isValidBackup` were reused
unchanged.

## Out of scope
- Any admin-chosen path for End-of-Day Save, routine backup, or restore (fixed by design).
- Scheduled/automatic periodic backups beyond the two manual actions.
- Keeping more than "the latest" backup discoverable for restore through the UI (older files
  remain on disk in the fixed folder but are not surfaced as restore choices — restore is always
  "latest," by design, to keep the flow picker-free and unambiguous).
