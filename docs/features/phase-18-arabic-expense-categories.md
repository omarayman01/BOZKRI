# Phase 18 — Expense Categories in Arabic

[← Back to roadmap index](../FEATURES_ROADMAP.md)

## Goal
Every expense category the app ships with is Arabic, matching Phase 1's global "100% Arabic"
rule — closing a spot that rule missed. Today `AppDatabase._seedExpenseCategories()` seeds six
categories in English ("Rent", "Salaries", "Utilities", "Marketing", "Transport", "Other"), and
every fresh install (and every existing install that already ran that seed) shows these English
values in the category dropdown (`add_edit_expense_screen.dart`) and the category column
(`expense_row.dart`, the dashboard's expenses breakdown card) for as long as the admin never
renames them.

## Depends on
None functionally. Independent of Phases 11–17.

## Schema deltas
None — `expense_categories.name` is already a free-text column; this phase changes seed **data**
and adds a one-time data migration, not the schema.

## State
No cubit/state change. `ExpensesCubit`/`ExpensesState` already read whatever `name` is stored;
once the stored value is Arabic, the existing dropdown and table columns display it correctly
with zero UI code changes.

## DAO / repo
- `database/local/app_database.dart`:
  - `_seedExpenseCategories()` — the six defaults become إيجار، رواتب، مرافق، تسويق، مواصلات،
    أخرى (an admin can still rename or add categories freely afterward; this only changes what a
    **fresh** install starts with).
  - `schemaVersion` bumps to `7`; `migration.onUpgrade` gains an `if (from < 7)` step that
    `UPDATE`s any existing `expense_categories` row whose `name` exactly matches one of the six
    original English defaults to its Arabic equivalent (exact-match only — an admin-renamed or
    admin-added category is never touched, since there is no reliable way to tell an admin's own
    English category name from a stale seed value other than exact string identity with what the
    app itself used to seed).

## UI
No new widgets. The existing category dropdown and every place `categoryName` is rendered
(`expense_row.dart`, `expenses_breakdown_card.dart`) already just display the stored string —
once that string is Arabic, no further UI change is needed.

## Localization
No new l10n keys — category names are data, not app strings, and were never part of the arb
files. This phase only changes what data the seed/migration writes.

## Acceptance criteria
- [ ] A brand-new install seeds exactly six Arabic expense categories: إيجار، رواتب، مرافق،
      تسويق، مواصلات، أخرى — no English category name appears anywhere.
- [ ] An existing install upgrading through this phase has any of its six original English
      default category names (if still present, unrenamed) relabeled to the matching Arabic
      name, in place — same row id, so every expense already linked to that category keeps
      pointing at the same (now Arabic) category with zero data loss.
- [ ] A category the admin already renamed away from the English default, or added themselves,
      is never touched by the migration, English or otherwise.
- [ ] The expense category dropdown, the Expenses tab table, and the dashboard's expenses
      breakdown card all show the Arabic names with no code change beyond the seed/migration.

## Out of scope
- Translating or validating admin-typed category names — an admin who types an English name
  today is free to do so; this phase only fixes the app's own seed data.
- Any change to how categories are created, edited, or deleted (`addCategory`/`deleteCategory`
  are unchanged).
