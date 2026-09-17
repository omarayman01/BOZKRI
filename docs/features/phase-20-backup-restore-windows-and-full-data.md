# Phase 20 — Backup/Restore: Windows Hardening + Item Types in the Excel Restore

[← Back to roadmap index](../FEATURES_ROADMAP.md)

## Goal
Two independent hardening passes over Phase 11's backup/restore, aimed at the real scenario of
selling/updating this app on a client's Windows machine: **(1)** make the file-level backup/
restore mechanism robust to Windows-specific file-locking behavior, and **(2)** let the `.xlsx`
restore path bring back item **types** (not just items), so an admin who backs up, installs an
app update, and restores can rebuild their whole catalog — types, fields, and items — from the
Excel report alone if the `.sqlite` file is ever unavailable, in addition to the `.sqlite`
restore already being the full-fidelity path for everything (including every deal).

## Depends on
Phase 11 (the two-button backup/restore this phase hardens and extends) and Phase 15 (Cars tab,
unaffected but sharing the same `items`/`item_types` tables the Excel restore now also covers).

## Schema deltas
None.

## Part 1 — Windows file-handling hardening

### Problem
`DbBackupHelper.restoreFromSqlite` deletes the current database's `-wal`/`-shm` sibling files
right after `checkpointAndClose()`, and copies the safety-copy and the new file over the top of
the live one — all in quick succession. On Windows, closing a native SQLite handle (via
`sqlite3_flutter_libs`' FFI binding) does not always release the OS-level file lock in the same
call tick as `close()` returns — antivirus scanning and delayed handle teardown are common
additional causes — so a `FileSystemException` ("used by another process" / access-denied) on
one of these operations is a realistic, Windows-specific failure mode that would otherwise abort
an entire restore that should have succeeded.

### DAO / repo
- `utils/db_backup_helper.dart`:
  - A new private retry helper, `_withRetry<T>(Future<T> Function() op, {int attempts = 5,
    Duration delay = const Duration(milliseconds: 150)})`, used around every filesystem
    operation that immediately follows `checkpointAndClose()`: the safety-copy of the current
    file, deleting each `-wal`/`-shm` sibling, and the final `source.copy(target.path)`. Retries
    only on `FileSystemException`; any other exception (e.g. a genuinely invalid file) still
    fails immediately, unretried.
  - `checkpointAndClose()` (on `AppDatabase`) itself gets one retry around the
    `wal_checkpoint(TRUNCATE)` statement for the same reason — a checkpoint can transiently fail
    if a reader has not yet released its snapshot.
  - No change to the safety-copy-first, validate-before-touching-the-live-file ordering Phase 11
    already established — retries wrap the same steps, they don't reorder them.

### Acceptance criteria
- [ ] A simulated transient file-lock (`FileSystemException`) on the WAL/SHM cleanup or the
      final copy step is retried up to 5 times with a short delay before the restore is reported
      as failed; a lock that never clears still eventually fails with the existing clear Arabic
      error message, it just doesn't fail prematurely on the first transient hit.
- [ ] No behavior changes on the happy path (macOS/Linux, or Windows with no lock contention):
      same files written, same safety-copy behavior, same validation-before-write guarantee.
- [ ] Backup and restore file paths continue to work with Windows-style paths (`C:\Users\...`,
      backslash separators) exactly as they already do via the `path` package's platform-aware
      `Context` — this phase does not change path construction, only retries around file ops.

## Part 2 — Item types in the `.xlsx` restore

### State
- `utils/excel_import_helper.dart` — `MasterDataImportSummary` gains `itemTypesCreated` and
  `fieldsCreated` counts, folded into the existing success-message summary.

### DAO / repo
- `utils/excel_export_helper.dart` — new `_writeItemTypesSheet(workbook, itemTypes)`: one sheet
  named `ItemTypes`, one row per (item type, field) pair — النوع, اسم الحقل, نوع الحقل
  (`FieldType.name`: text/number/date/bool — the same raw value `FieldType.fromName` already
  round-trips), إلزامي (نعم/لا), الترتيب — plus a single row for any item type with zero fields
  (اسم الحقل blank) so the type itself is never silently dropped from the sheet. Called from
  `exportEndOfDayWorkbook` alongside the existing `_writeItemsSheet`/`_writeSuppliersSheet` calls.
- `utils/excel_import_helper.dart` — `importMasterData` gains an `ItemTypes` pass, run **before**
  the existing `Items` pass (which already requires a matching item type by name to place a
  row): for each distinct النوع in the sheet, `addType` if no existing type matches that name;
  for each (type, field) row, upsert the field by (`itemTypeId`, `fieldName`) — `addField` if no
  existing field matches that name under that type, `updateField` if one does and its
  `fieldType`/`isRequired`/`sortOrder` differ from the sheet's row. An item type or field that
  already exists identically is left untouched (no duplicate rows, no unnecessary writes).

### UI
- `view/features/settings_features/widgets/restore_tile.dart` — the `.xlsx` disclaimer dialog's
  text is extended to name item **types** alongside items: "هذا الاستيراد يجلب العملاء والموردين
  وأنواع الأصناف وحقولها والأصناف/السيارات — لا يجلب الصفقات أو الدفعات أو الأرصدة."
- No other UI change — the success message already surfaces created/updated counts generically.

### Localization
Updated: the `.xlsx` restore disclaimer string above. New: whatever column headers
`_writeItemTypesSheet` introduces (النوع, اسم الحقل, نوع الحقل, إلزامي, الترتيب) — plain sheet
text, not app l10n keys, consistent with every other export sheet's headers.

### Acceptance criteria
- [ ] A `.sqlite` backup's paired `.xlsx` report includes an `ItemTypes` sheet listing every item
      type and its full field schema (name, type, required, order).
- [ ] Restoring that `.xlsx` on a machine with an empty (freshly installed/updated) database
      recreates every item type and every one of its fields before recreating the items that
      belong to them, so no item is skipped for "unknown item type" the way it would be today.
- [ ] Restoring the same `.xlsx` a second time against data that already has those types/fields
      creates no duplicates — every type and field is matched by name and left as-is (or
      updated in place if its stored definition differs from the sheet).
- [ ] The `.xlsx` restore still never touches `transactions`/`transaction_items`/`payments`/
      `refunds` — this phase only widens the master-data set it covers, it does not change what
      counts as master data vs. transactional data.
- [ ] The restore disclaimer dialog's Arabic text accurately lists everything the import now
      brings back.

## Out of scope
- Importing transactional data (deals/payments/refunds) from Excel in any form — still strictly
  the `.sqlite` restore's job, per Phase 11.
- Any change to the `.sqlite` backup/restore's own data coverage — it already copies the entire
  database file byte-for-byte, so it already includes item types, fields, items, and everything
  else; this phase's Part 2 only closes the gap in the **Excel** path specifically.
- A general redesign of the "every backup/restore permanently closes the DB connection and
  requires an app restart" constraint — that limitation (Drift connections cannot be reopened)
  is unchanged and is not what "Windows hardening" means in this phase.
