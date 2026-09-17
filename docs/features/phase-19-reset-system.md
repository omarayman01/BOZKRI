# Phase 19 — Reset System (Settings)

[← Back to roadmap index](../FEATURES_ROADMAP.md)

## Goal
Give the admin a single Settings button that wipes every deal, payment, refund, expense,
client, supplier, and item — a clean slate for re-selling/re-deploying the app, or recovering
from bad test data — while keeping the admin's own configuration (item types + their dynamic
field schemas, and expense categories) intact, so the app isn't left completely unconfigured
afterward.

## Depends on
None functionally. Independent of Phases 11–18.

## Schema deltas
None. This phase deletes rows; it adds no column and no table.

## State
- `cubit/settings/settings_cubit.dart` gains `Future<bool> resetSystem()`.
- `cubit/settings/settings_state.dart` — `SettingsAction` gains `reset`; `SettingsStep` gains
  `wiping` (the whole operation is one step — there is no meaningful sub-phase breakdown the
  admin needs to see, unlike backup/restore's multi-file flow).
- Unlike backup/restore, `resetSystem` does **not** close the live database connection — it
  deletes rows over the same open connection, then the caller reloads every cache/cubit in
  place (`ClientsCubit.load`, `SuppliersCubit.load`, `ItemTypesCubit.load`,
  `ItemsCubit.loadAll`, `DealsCubit.loadDeals`, `ExpensesCubit.load`, `DashboardCubit.load` —
  the same sequence `MainShell._bootstrapData` already runs at startup) — so **no app restart is
  required**, unlike every `.sqlite`-touching backup/restore action.

## DAO / repo
- `database/local/app_database.dart` — `Future<void> resetAllData()`, wrapped in one
  `transaction()`:
  1. `delete(transactions)` with no `where` — cascades to `transaction_items`, `payments`,
     `refunds` → `refund_items`, and any `expenses` row still carrying that `transaction_id`
     (commission-linked expenses), per the cascades already declared in `tables.dart`.
  2. `delete(expenses)` with no `where` — removes every remaining (non-transaction-linked)
     expense. `expense_categories` themselves are **not** deleted (`categoryId`'s
     `onDelete: KeyAction.setNull` means this step alone would never touch them anyway).
  3. `delete(items)` with no `where` — cascades to `item_field_values`. `item_types` and
     `item_type_fields` are **not** deleted.
  4. `delete(suppliers)` with no `where` — safe now that `items` (the only referencing table)
     is empty.
  5. `delete(clients)` with no `where` — safe now that `transactions` (the only referencing
     table) is empty.
  This exact order is required: `items`/`transactions` must go before the `suppliers`/`clients`
  they reference, since those foreign keys are plain `.references(...)` (`NO ACTION`), not
  cascading, and `PRAGMA foreign_keys = ON` is already set for every connection.
- `repos/settings_repo.dart` (new, or a method added to an existing repo the `SettingsCubit`
  already holds) — thin pass-through to `resetAllData()`, following the same repo-wraps-DAO
  pattern every other write path in this app already uses.

## UI
- `view/features/settings_features/widgets/reset_system_tile.dart` (new) — a third, visually
  separated, destructive-styled tile at the bottom of Settings' data section: "إعادة تعيين
  النظام", one button. On press: a plain-Arabic `ConfirmDialog` (matching the app's existing
  destructive-action pattern, e.g. `deal_detail_screen.dart`'s delete confirmation) naming the
  concrete consequence — every client, supplier, item, deal, payment, refund, and expense will
  be permanently deleted; item types and expense categories are kept — with `isDestructive:
  true` and an explicit warning line, no forced backup step (the confirmation dialog alone is
  the safety net, same weight as every other irreversible delete already in this app; the admin
  remains free to back up first via the adjacent Backup tile — the dialog's body reminds them of
  that option in one line).
- On success: a plain Arabic success message ("تم إعادة تعيين النظام."), then the tile itself
  triggers the same cache/cubit reload sequence `MainShell` runs at startup (via a callback
  or by the admin simply switching tabs — implementer's discretion — the requirement is that
  every screen reflects the empty state immediately, with no stale cached list anywhere).
- Still wrapped in `blocking_progress_overlay.dart` like every other disk/DB-touching action in
  this app, with an Arabic status line ("جاري إعادة التعيين…").

## Localization
New labels: إعادة تعيين النظام, سيتم حذف جميع العملاء والموردين والأصناف والصفقات والدفعات
والمرتجعات والمصروفات نهائياً — أنواع الأصناف وفئات المصروفات ستبقى كما هي, تم إعادة تعيين
النظام, يمكنك عمل نسخة احتياطية أولاً من الأعلى إذا أردت الاحتفاظ بالبيانات الحالية.

## Acceptance criteria
- [ ] After Reset, every client, supplier, item, deal, payment, refund, and expense is gone —
      the Deals/Clients/Suppliers/Cars/Expenses tabs and the dashboard all show their empty
      state — with no app restart required.
- [ ] Every configured item type and its dynamic field schema survives Reset unchanged; every
      expense category survives Reset unchanged (an admin can immediately add a new item or
      expense against an existing type/category with no reconfiguration).
- [ ] The confirmation dialog names the concrete consequence in plain Arabic and requires an
      explicit confirm click before anything is deleted; cancelling leaves every row untouched.
- [ ] Reset executes inside exactly one Drift transaction — a simulated failure mid-operation
      leaves the database in its pre-reset state, never partially wiped.
- [ ] Running a Backup immediately before Reset, then a `.sqlite` Restore afterward, fully
      recovers every row Reset deleted — Reset does not touch backup/restore's own mechanism.

## Out of scope
- Deleting item types, item type fields, or expense categories — those survive every Reset;
  clearing them (if ever wanted) would go through their own existing management screens
  (Settings' item-type manager, the Expenses tab's category management) or the full `.sqlite`
  restore-from-empty-file path, not this button.
- Any selective/partial reset (e.g. "only deals," "only this client") — Reset is all-or-nothing
  by design, matching how big/rare this action is meant to be.
