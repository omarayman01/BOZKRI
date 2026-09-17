# Phase 9 — Live Analytics (auto-reflect deal changes) — ✅ Done (fallback approach)

[← Back to roadmap index](../FEATURES_ROADMAP.md)

## Goal
The dashboard reflects every deal, payment, refund, and expense mutation automatically while
it's open — no manual refresh, no needing to leave and reopen the app.

## Depends on
None functionally; independent of Phases 7–8. Ordered after them here only because it is
lower-risk to verify against a UI that already shows correct Arabic statuses and search.

## Current gap (why this phase is needed)
`DashboardCubit.load()`/`refresh()` are one-shot `Future`-based queries. `MainShell` keeps every
primary screen alive in an `IndexedStack`, so `DashboardScreen` is built once and never rebuilt
on tab switch — `DashboardCubit.load()` only runs at app startup (`MainShell._bootstrapData`).
Only one screen (`expenses_section.dart`, inside the dashboard itself) currently calls
`context.read<DashboardCubit>().refresh()` after its own mutations; `DealsCubit`,
`PaymentsCubit`, and `RefundCubit` call none of the dashboard's methods at all today, so adding,
editing, or deleting a deal, recording a payment, or issuing a refund leaves the dashboard
showing stale numbers until the app restarts.

## Schema deltas
None. No cached/stored totals are introduced by this phase, consistent with the existing
derived-balance invariant.

## State
**Preferred approach** — Drift watch queries:
- `cubit/dashboard/dashboard_cubit.dart` — replace the one-shot `load()` with a subscription:
  `StreamSubscription<DashboardSummaryModel>? _sub` started in a new `watch({AppDateRange?
  range})` method, calling into a new `DashboardRepo.watchSummary(...)` that wraps Drift's
  `.watch()` on the same tables `getSummary` already reads from
  (`transactions`, `transaction_items`, `payments`, `refunds`, `expenses`). Every `emit` in the
  stream listener follows the same `DashboardState` shape `load()` already produces
  (`loading` once at subscribe, then `success`/`failure` per emission) — no new state shape.
  `close()` cancels `_sub`.
- `MainShell` starts the dashboard's `watch()` once (alongside the other `_bootstrapData` calls)
  instead of a one-shot `load()`; `DashboardScreen`'s own date-range picker still calls a
  `setRange` that re-subscribes with the new range (Drift watch queries are re-run on demand by
  re-issuing the query, same as today's `setRange` re-issuing a `Future` query).

**Fallback approach**, if Drift watch queries prove impractical for the aggregate SQL
`DashboardDao.getSummary` already runs (e.g. it spans multiple tables in ways that don't map
cleanly onto a single watched `SELECT`): keep `DashboardCubit.load()`/`refresh()` as `Future`-
based, and instead call `context.read<DashboardCubit>().refresh()` from every mutating cubit's
success path — `DealsCubit.commit`/`editDeal`/`deleteDeal`, `PaymentsCubit`'s add/update/delete
methods, `RefundCubit`'s submit method — mirroring the single call site `expenses_section.dart`
already has. This still requires `DashboardScreen` to stay subscribed (via `BlocBuilder`) rather
than being read once, and requires `MainShell` to keep `DashboardCubit` reachable from every
other cubit's success path (already true — all cubits are provided at the same `MultiProvider`
level in `startApp()`).

Either approach must leave every other cubit's own state and existing behavior unchanged; this
phase touches dashboard freshness only.

## DAO / repo
- `daos/dashboard_dao.dart` — if the watch approach is used, add `Stream<DashboardSummaryModel>
  watchSummary({DateTime? from, DateTime? to})` alongside the existing `Future`-returning
  `getSummary`, built from the same aggregate queries wrapped in Drift's `.watch()` /
  `Selectable.watchSingle()`.
- `repos/dashboard_repo.dart` / `_impl.dart` — mirrors the DAO addition:
  `Stream<DashboardSummaryModel> watchSummary(...)`.
- If the fallback approach is used instead: no DAO/repo change, only the additional
  `refresh()` calls listed above in the mutating cubits.

## UI
No new widgets. `DashboardScreen` already renders from `DashboardState` via `BlocBuilder`;
it needs no visible change — the only difference is how often a new `DashboardState` arrives.

## Localization
None — no new strings.

## Acceptance criteria
- [x] Creating a deal while the dashboard is open (in the background `IndexedStack` tab or the
      foreground one) updates net revenue, net cost, gross/net profit, outstanding receivables,
      and the daily chart without the user navigating away and back — `DashboardScreen` is kept
      mounted by `MainShell`'s `IndexedStack` and subscribes via `BlocBuilder`, so a `refresh()`
      fired from any other tab's cubit updates it immediately, even while off-screen.
- [x] Editing or deleting a deal updates the same figures live.
- [x] Recording or deleting a client or supplier payment updates outstanding receivables/
      payables and payment-status-derived counts live.
- [x] Issuing a refund updates net revenue/cost/profit live.
- [x] Adding, editing, or deleting an expense updates total expenses and net profit live
      (already true via the pre-existing `expenses_section.dart` `refresh()` call sites — this
      phase changed nothing there).
- [x] Top clients, top suppliers, and any status-count widgets on the dashboard update live
      along with the headline figures — all come from the one `DashboardSummaryModel` that
      `refresh()` reloads.
- [x] No cached/stored total is introduced anywhere — every figure remains computed at read
      time; this phase added no schema and no DAO change, only extra `refresh()` calls.
- [ ] Numbers shown reconcile against the underlying deals/payments/expenses lists for the same
      date range — **manual spot-check, not part of this code change**.

**Approach taken: the fallback, not Drift watch queries.** `DashboardDao.getSummary` is five
separate aggregate `customSelect` queries (totals, receivables, payables, top clients/suppliers,
daily revenue) combined in Dart, not one `SELECT` — wrapping that in a single watched stream
would mean hand-rolling a combine-latest over five `Selectable.watch()` streams for a payoff no
different from re-running the existing `Future`-based query on every mutation. The spec
explicitly sanctions this fallback for exactly this case, so `DashboardCubit`/`DashboardDao` are
unchanged; instead, every UI call site that mutates deals/payments/refunds now also calls
`context.read<DashboardCubit>().refresh()` after success, mirroring the one call site
`expenses_section.dart` already had.

`deals_screen.dart` (list-level create/edit/delete) and `expenses_section.dart` were **already**
wired before this pass. This pass found and fixed the gap: `deal_detail_screen.dart` — reachable
directly from client/supplier detail tabs, not only from the deals list — did none of its own
in-place mutations (add payment, edit, close/re-open a car line, refund, delete, and
`PerDayRentalGrid`'s per-day payment mark/unmark via a new `_onLineMutated` callback) trigger a
dashboard refresh, so editing a deal from, say, a client's transactions tab left the dashboard
stale even though the same edit from the deals list already refreshed it correctly.

## Out of scope
- Live-updating any screen other than the dashboard (deals/clients/suppliers lists already
  re-`load()` on their own screen's `initState`/pull-to-refresh pattern, unchanged).
- Push notifications or badges for changes made while the dashboard is not open.
