# Phase 13 — Expense Notes Visible in Analytics

[← Back to roadmap index](../FEATURES_ROADMAP.md)

## Goal
The dashboard's expenses breakdown shows each expense's notes (ملاحظات) alongside its title,
category, and amount, so an admin scanning the dashboard doesn't have to open the Expenses tab
to see why a given expense was recorded.

## Depends on
Phase 12 (the Expenses tab is the canonical place notes are entered/edited; this phase only adds
visibility of the existing `expenses.note` field to the dashboard's aggregate view).

## Schema deltas
None. `expenses.note` (ملاحظات) already exists and is already loaded by `ExpensesRepo`/
`DashboardDao` wherever expenses are read.

## State
No cubit/state shape change — `ExpenseModel.note` is already populated on every expense read;
this phase is a presentation change to whichever dashboard widget lists expenses.

## DAO / repo
None — no query currently omits `note`; if the dashboard's own expenses-breakdown query
(`DashboardDao` or a dedicated repo call) selects a narrower column set that excludes it,
extend that `SELECT`/mapper to include `note`, mirroring how every other note/description field
in this app is already threaded through its row mapper.

## UI
- The dashboard's expenses-breakdown widget (wherever it lives after Phase 12 relocates the
  itemized CRUD list — likely a compact "أحدث المصروفات" or per-category breakdown card that
  stays on the dashboard) — each row gains either:
  - an expandable/tappable row that reveals ملاحظات inline, or
  - a dedicated ملاحظات column/line under the title, truncated with an ellipsis and a tooltip
    or "…" affordance for long notes,

  at the implementer's discretion — the requirement is that the note is visible **without
  navigating away from the dashboard**, not a specific layout.

## Localization
No new labels beyond ملاحظات, already established everywhere else in the app (payments, refund
reasons, etc.).

## Acceptance criteria
- [ ] An expense with a non-empty `note` shows that note directly in the dashboard's expenses
      view, without navigating to the Expenses tab.
- [ ] An expense with no note shows no empty/placeholder note row (blank notes stay invisible,
      consistent with how notes are handled elsewhere in the app).
- [ ] The note shown on the dashboard always matches the note last saved on that expense via the
      Expenses tab — no separate copy, no staleness.

## Out of scope
- Editing a note directly from the dashboard — the dashboard view is read-only; editing still
  happens on the Expenses tab.
