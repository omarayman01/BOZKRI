# Agency Management System — build & run

Fully-offline Flutter desktop app (macOS + Windows). No network calls anywhere.

## 1. Generate the native runners (once)

```bash
cd agency_management_system
flutter create . \
  --project-name agency_management_system \
  --org com.agency \
  --platforms=macos,windows
```

This only adds `macos/` and `windows/`; it will not overwrite `pubspec.yaml`,
`lib/`, `l10n.yaml` or `analysis_options.yaml`.

## 2. Bundled fonts (required — nothing is fetched at runtime)

Download the **Tajawal** family (SIL Open Font License) and drop these three
files into `assets/fonts/`:

- `Tajawal-Regular.ttf`
- `Tajawal-Medium.ttf`
- `Tajawal-Bold.ttf`

Tajawal covers both Arabic and Latin glyphs, so the UI does not swap fonts
between locales. The `fonts:` block in `pubspec.yaml` already declares them.

## 3. Install packages and run code generation

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

Code generation produces:

- `lib/model/*.freezed.dart` — freezed models
- `lib/view_model/database/local/app_database.g.dart` — Drift database
- `lib/view_model/database/local/daos/*.g.dart` — Drift DAO mixins
- `lib/l10n/app_localizations.dart` — from the ARB files (produced by
  `flutter pub get` / `flutter run`, driven by `l10n.yaml`)

Run it again after any change to a table, model or ARB file.

## 4. Run

```bash
flutter run -d macos
flutter run -d windows
```

## 5. Platform notes

### macOS entitlements

Backup and restore use a file picker, so in both
`macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements`
ensure:

```xml
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```

Do **not** add `com.apple.security.network.client` — the app is fully offline.
Set the deployment target to 10.14+ in `macos/Podfile` if it is lower.

### Windows / sqlite3

`sqlite3_flutter_libs` copies `sqlite3.dll` into the build output. After

```bash
flutter build windows --release
```

verify `sqlite3.dll` sits next to `agency_management_system.exe` in
`build\windows\x64\runner\Release\`, then copy the **whole folder** to a clean
machine with no SQLite installed and confirm the app opens and writes data.

## Architecture

| Concern | Owner |
|---|---|
| DB I/O, async, loading/success/failure | Cubits (`view_model/cubit/**`) |
| Shared in-memory state and caches | Providers (`view_model/provider/**`) |
| SQL and transactions | Drift DAOs (`view_model/database/local/daos/**`) |
| Failure mapping | `view_model/errors/**` |
| Composition root | `startApp()` in `lib/app.dart` |

`AppDatabase` is constructed and awaited **before** `runApp`, then injected into
the repository implementations. There is no DI container — everything is wired
by hand in `startApp()` via `MultiProvider` and `BlocProvider.value`.

### Invariants worth knowing

- **Snapshots.** `transaction_items.unitCost/unitPrice` and
  `refund_items.unitCost/unitPrice` are captured at deal time. No analytics
  query joins live item prices, so editing an item's defaults never changes a
  past figure.
- **Derived balances.** Receivables, payables and payment status are computed
  from payments and refunds; nothing is stored. That is why full admin edit and
  delete are safe at any time.
- **Per-supplier payables.** A supplier's payable is their own line costs inside
  one transaction, net of refunded cost, minus payments carrying their
  `supplierId` — never the whole `totalCost`.
- **Single-use dual enforcement.** The item picker filters out consumed
  single-use items, and `TransactionsDao._assertSingleUseAvailable` re-checks
  inside the write transaction, throwing `ItemUnavailableFailure` and rolling
  everything back.
- **Atomicity.** Commit, edit, delete and refund are each one Drift transaction.
- **Foreign keys.** `PRAGMA foreign_keys = ON` runs in `beforeOpen`; without it
  SQLite silently ignores every `ON DELETE CASCADE`.
- **Backups.** `DbBackupHelper` checkpoints the WAL and closes the connection
  before copying, so a backup is never WAL-inconsistent. The app must be
  relaunched afterwards.

### Localization

Language is an explicit override in `SettingsProvider` (persisted via
SharedPreferences), deliberately independent of the device locale. Arabic flips
the app to RTL through the `Directionality` in `AgencyApp.builder`, which puts
the side rail on the right and reverses the deal-builder pane order. Money and
dates are pinned to `en_US` number formatting so digits stay Western and LTR in
both languages; chart axis labels are wrapped in an explicit LTR
`Directionality`.
