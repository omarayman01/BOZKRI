# Phase 16 — Commission Reflects in Analytics Instantly

[← Back to roadmap index](../FEATURES_ROADMAP.md)

## Goal
Confirm and, where needed, close any remaining gap so that setting, changing, or clearing a
deal's commission is reflected on the dashboard's expenses total and net profit immediately,
with no manual refresh — closing the loop between Phase 5's commission-as-linked-expense
mechanism and Phase 9's live-analytics refresh plumbing.

## Depends on
Phase 5 (commission creates/updates/deletes a linked "عمولة" expense) and Phase 9 (every
deal-mutating UI call site already calls `DashboardCubit.refresh()` after a successful save) —
both already shipped; this phase is a targeted verification/closure pass, not new mechanism.

## Schema deltas
None.

## State
No new state. `DealsCubit.commit`/`editDeal` already call `_syncCommissionExpense` inside the
same Drift transaction as the deal save (Phase 5), and every UI call site that invokes
`commit`/`editDeal` already calls `context.read<DashboardCubit>().refresh()` afterward (Phase 9)
— this phase's job is to verify that chain is unbroken for commission specifically, and fix it
if not.

## DAO / repo
No change expected. If verification finds a call site that saves a deal (with a commission
change) but does not currently trigger a dashboard refresh — e.g. a path Phase 9's audit missed
— extend that call site the same way Phase 9 already extended every other one, rather than
introducing a new, parallel refresh mechanism.

## UI
No new widgets. The dashboard's expenses total and net-profit KPIs already re-render on any
`DashboardCubit.refresh()`; this phase verifies commission changes reach that call, same as any
other expense-affecting change already does per Phase 9's fallback-refresh design.

## Localization
None — no new strings.

## Acceptance criteria
- [ ] Setting a commission on a new or existing deal makes the dashboard's expenses total and
      net profit reflect it immediately upon returning from the save — no manual refresh, no
      re-navigating to the dashboard first.
- [ ] Reducing a commission to zero or clearing it removes its linked expense and the dashboard
      reflects the reversal immediately, the same way.
- [ ] Editing a commission's amount (without clearing it) updates the same linked expense in
      place and the dashboard shows the new amount immediately — no duplicate expense, no stale
      figure.
- [ ] No new call site introduces a second, divergent refresh path — every commission-triggered
      dashboard update goes through the same `DashboardCubit.refresh()` every other Phase 9 call
      site already uses.

## Out of scope
- Any change to how commission itself is entered, validated, or linked to an expense — that
  mechanism is Phase 5's and is unchanged here.
- Any change to `DashboardCubit`'s refresh mechanism itself (still the Phase 9 fallback
  approach) — this phase only ensures commission changes are covered by it.
