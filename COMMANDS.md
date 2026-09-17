# Commands — run, build, clean

Quick command reference for day-to-day work on this project. For first-time
machine setup (native runners, fonts, entitlements), see [SETUP.md](SETUP.md)
instead — this file assumes that's already done.

## Run

```bash
flutter run -d macos
flutter run -d windows
```

List available targets first if unsure:

```bash
flutter devices
```

## Code generation

Run this after any change to a Drift table (`lib/view_model/database/local/tables.dart`),
a `@freezed` model (`lib/model/*.dart`), or an ARB file (`lib/l10n/*.arb`):

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

`--delete-conflicting-outputs` skips the interactive "overwrite?" prompt —
always safe here since generated files are never hand-edited.

## Build (release)

```bash
flutter build macos --release
flutter build windows --release
```

Output lands in `build/macos/Build/Products/Release/` and
`build\windows\x64\runner\Release\`. On Windows, confirm `sqlite3.dll` sits
next to the `.exe` before copying the folder to another machine (see
[SETUP.md](SETUP.md#windows--sqlite3)).

## Clean build artifacts

Wipes `build/`, `.dart_tool/`, and platform build caches — use when a build
misbehaves after a Flutter/package upgrade or a platform-file change. This
does **not** touch app data or the database on any machine the app is already
installed on; it only cleans this source checkout.

```bash
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

## Clean the local database (dev machine)

The app is offline-first: all data lives in one SQLite file in the OS's
per-app "Application Support" directory, named `agency_management.sqlite`
(`AppConstants.dbFileName`). Deleting it gives you a fresh database on next
launch — Drift's `onCreate` recreates every table and reseeds the default
expense categories.

**Before deleting, quit the app** (Drift holds the file open with WAL
journaling; deleting while it's running just gets a new file recreated
underneath the old handle, which is confusing but harmless).

**1. Find the file** (path varies by bundle id / sandbox container, so search
for it rather than assuming a fixed path):

```bash
# macOS
find ~/Library/Containers ~/Library/'Application Support' \
  -iname 'agency_management.sqlite*' 2>/dev/null
```

```powershell
# Windows (PowerShell)
Get-ChildItem -Path $env:LOCALAPPDATA,$env:APPDATA -Recurse `
  -Filter 'agency_management.sqlite*' -ErrorAction SilentlyContinue
```

**2. Delete the database file and its sidecars.** SQLite in WAL mode keeps
two extra files next to the main one (`-wal`, `-shm`); delete all three so no
uncommitted WAL data resurfaces:

```bash
rm -f "<found-path>/agency_management.sqlite" \
      "<found-path>/agency_management.sqlite-wal" \
      "<found-path>/agency_management.sqlite-shm"
```

Also remove any `agency_management.sqlite.pre-restore` file in the same
folder — that's the automatic safety copy `DbBackupHelper` makes before a
restore, not something the app reads on startup, but worth clearing out
during a full reset.

**3. Relaunch.** `AppDatabase.open()` creates a new file and runs `onCreate`.

### Schema version note

The database is currently at **`schemaVersion = 5`** (`app_database.dart`),
after the End-of-Day Save, client ID fields, car per-day pricing, kilometer
settlement, and commission/override phases. A deleted-and-recreated database
always starts at the latest schema — the version number only matters for
**upgrading an existing file** (Drift's `onUpgrade` runs the migration steps
for whichever version that file was last opened at). If you add a new column
or table, bump `schemaVersion` and add a matching `if (from < N)` branch in
`onUpgrade`, the same pattern as the existing five steps.

### Prefer not to delete data?

Use the in-app **Settings → End-of-Day Save** to write a timestamped
`.sqlite` backup first, or **Settings → Restore from backup** to swap in a
known-good database instead of starting from empty — both are safer than a
manual file delete when there's real data you might want back.
