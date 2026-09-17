# Phase 12 — Expenses as a Dedicated Tab

[← Back to roadmap index](../FEATURES_ROADMAP.md)

## Goal
Promote Expenses from a section embedded in the dashboard to a first-class side-nav
destination, so it has its own dense list, its own add/edit/delete flow, and its own date-range
filter — the same shape every other list screen (Deals, Clients, Suppliers) already has.

## Depends on
None functionally; a UI/navigation promotion of the existing, already-working
`cubit/expenses/expenses_cubit.dart` and its DAO/repo.

## Schema deltas
None. `expenses` and `expense_categories` already exist and are unchanged.

## State
- `cubit/expenses/expenses_cubit.dart` — unchanged; already exposes `load({AppDateRange?
  range})`, `setRange`, `addExpense`, `updateExpense`, `deleteExpense`, `addCategory`.
- `cubit/expenses/expenses_state.dart` — unchanged.
- `view/core/navigation/main_shell.dart` — the side-nav item list gains المصروفات as its own
  entry with its own `IndexedStack` slot (kept alive like every other primary tab), positioned
  per the RTL nav order: الصفقات، العملاء، الموردون، السيارات (Phase 15)، المصروفات، لوحة
  المعلومات، plus the settings gear.

## DAO / repo
None new — `daos/expenses_dao.dart` / `repos/expenses_repo.dart` already provide everything a
standalone list screen needs (`getExpenses(range)`, `addExpense`, `updateExpense`,
`deleteExpense`, category lookups).

## UI
- `view/features/expenses_features/expenses_screen.dart` (new) — a dense RTL table (date,
  title/العنوان, category/الفئة, amount/المبلغ, notes/ملاحظات), a date-range filter matching the
  one already used on the dashboard, a range total, and one dominant "إضافة مصروف" primary
  action, edit/delete icons per row — the same list-screen shape `deals_screen.dart`/
  `clients_screen.dart` already establish.
- `view/features/expenses_features/add_edit_expense_screen.dart` (new, or a promoted dialog if
  the existing add/edit dialog from the dashboard section already covers the fields) — title,
  category (existing category picker + "إضافة فئة" inline), amount, date, notes.
- `view/features/expenses_features/widgets/expense_row.dart` (new) — one row's cells, mirroring
  `deal_row.dart`'s per-column `DataCell` pattern.
- The dashboard's existing `expenses_section.dart` embedded widget is removed from the dashboard
  screen; the dashboard's *aggregate* expenses figure (total for the selected range, feeding net
  profit) stays on the dashboard as a KPI, unchanged — only the itemized list/CRUD UI moves to
  the new tab.
- `view/core/navigation/app_routes.dart` — a new route for the Expenses tab/screen, wired into
  `MainShell`'s `IndexedStack` alongside the existing primary destinations.

## Localization
New labels: المصروفات (nav item + tab title), العنوان, الفئة, إضافة مصروف — several of these
likely already exist from the dashboard's embedded section and are reused verbatim, not
retranslated.

## Acceptance criteria
- [ ] المصروفات appears as its own side-nav destination, in the RTL order given above, and
      stays mounted (state preserved) when switching to another tab and back, matching every
      other primary destination's `IndexedStack` behavior.
- [ ] The Expenses tab supports full create/edit/delete, exactly as the dashboard's embedded
      section did before the move — no capability regression.
- [ ] The date-range filter and its total match what the same range would show via the
      dashboard's aggregate expenses KPI (same underlying query, same numbers).
- [ ] The dashboard no longer embeds the itemized expenses list/CRUD UI, but its aggregate
      expenses figure (feeding net profit) is unchanged and still live per Phase 9.

## Out of scope
- Any change to what counts as an expense or how net profit aggregates them — this phase only
  relocates the UI.
- Expense categories management beyond what already exists (inline "إضافة فئة").
