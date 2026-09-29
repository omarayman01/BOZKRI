# Agency Management System — Features Roadmap

This document is a phased spec/roadmap for the next revision of the existing offline Flutter
desktop Agency Management System (BOZKRI). It describes **what** to build and **how** each
feature fits the existing architecture — schema deltas, state, DAO/repo surface, UI location,
localization, and acceptance criteria. It is spec + schema + acceptance criteria only: column
lists and query/method names are given where useful, but widget/function bodies are not. No
implementation code is included.

This revision supersedes any prior roadmap draft: the app becomes **Arabic-only** and every
screen gets simpler, and car-deal creation, closing, and backup/restore behavior all change
shape (dates/days/time sync together; kilometer settlement becomes optional and reversible).
Backup/restore itself has been redesigned twice since: Phase 6 first moved it to fixed,
picker-free locations, and Phase 11 (below) replaces that with a simpler two-button,
admin-chosen-destination design — see Phase 11 for the current behavior.

**Phases 1–10 are done and shipped.** Phases 7–10 were the last completed batch: making every
status label Arabic everywhere (closing a couple of spots the Phase 1 string sweep missed),
widening deal search to client/supplier name *and* phone, making the dashboard update live
instead of only at app startup, and fixing a real data-loss bug where editing a deal silently
deleted its per-day rental payments.

**Phases 11–17 are done and shipped.** They replaced Phase 6's backup/restore design with a
simpler two-button flow (Phase 11 supersedes Phase 6 — see the note on Phase 6's entry below),
promoted Expenses to its own tab with supplier-payment visibility that doesn't distort net
profit, added a fleet-registry Cars tab, made commission changes reflect in analytics without a
manual refresh, and made the deals list item-led instead of number-led.

**Phases 18–20 are done and shipped.** They fixed the last English seed data (expense category
defaults), added a full-wipe "Reset System" button to Settings, and hardened backup/restore for
the real update scenario: back up (`.sqlite` + `.xlsx`), install an app update on the client's
Windows machine, restore — including hardening the file operations against Windows-specific
file-locking and expanding the `.xlsx` restore to cover item types too.

**Phases 21–22 are newly added and pending — they reverse this document's own prior scope.**
The admin has decided the system should stop being single-device/offline-only: Phase 21 makes a
free Supabase (hosted Postgres + Auth) project the shared online database (with a local SQLite
cache and an offline warning badge so the app still works with no internet), and Phase 22 adds
real login/register accounts via Supabase Auth so every action can be attributed to a user.
(An earlier draft of both phases used Google Sheets; that was replaced with Supabase after review
— Sheets has no real transactions, no concurrency control, and API quotas that don't fit this
app's money-safety invariants, whereas Supabase is a real Postgres database with built-in Auth,
still free with no credit card at this app's expected scale.) Both phases still carry a couple of
open decisions for the admin before implementation starts — see each phase file.

Three small pending bugs were also fixed in this pass (not their own phase, since they're
one-line-scope corrections to already-shipped Phase 3/4/15 behavior): the car rental day count
was counting both the start and end date as full days (16→17 showed as 2 days instead of 1); a
car line's allowed-kilometers-per-day now defaults to 120 (still freely editable) instead of 0;
and the "why doesn't a newly added item-type field show up without restarting" report was
investigated — the current code already re-reads the field schema live on every form rebuild, so
if this still reproduces on the latest build it needs a fresh repro (exact steps + whether
`build_runner` was re-run) rather than a code fix, since no stale-cache path was found.

Every phase — done or pending — now has its own file under `docs/features/`; this page is just
the shared context and an index. Open a phase's file for its full
goal/schema/state/DAO/UI/localization/acceptance detail.

## Legend

- **Cubit** — `flutter_bloc` `Cubit`, used for DB I/O and async/loading/error state.
- **Provider** — `ChangeNotifier` via `provider`, used for shared/cross-screen UI state (theme,
  nav selection, etc.), not DB I/O.
- **Drift** — the SQLite ORM/query layer under `lib/view_model/database/local/`.
- **DAO** — a Drift `DatabaseAccessor` in `lib/view_model/database/local/daos/`.
- **Repo** — an interface + impl pair in `lib/view_model/repos/` that a cubit depends on.
- **Snapshot field** — a price/cost value copied onto a transaction/refund line at the time of
  the transaction, so later edits to catalog data never retroactively change historical money.
- **Derived value** — a value computed at read time from `payments`, `transaction_items`,
  `refund_items`, etc.; never persisted as a standalone stored column.
- **Item-type dynamic fields** — the existing `item_types` / `item_type_fields` /
  `item_field_values` system that lets each item type (apartment, flight, car, …) carry its own
  free-form attributes without new tables.
- ايجار الشقق = apartment rentals, تذاكر الطيران = flight tickets, ايجار السيارات = car rentals,
  معرض = supplier/dealer daily cost, مكتب = office/client daily price, ساري = active/open,
  غير ساري = closed/settled.

## Dependency-ordered phase list

1. [Phase 1 — Full Arabic Conversion + UX Simplification](features/phase-01-arabic-conversion.md) — ✅ **Done**
2. [Phase 2 — Branding + Client Identity Fields](features/phase-02-branding-client-identity.md) — ✅ **Done**
3. [Phase 3 — Car Deal Creation: Days ↔ Dates ↔ Time (linked)](features/phase-03-car-deal-creation.md) — ✅ **Done**
   (depends on Phase 1 for Arabic labels on new fields)
4. [Phase 4 — Close Deal + Kilometer Settlement, re-openable](features/phase-04-close-deal-km-settlement.md) — ✅ **Done**
   (depends on Phase 3)
5. [Phase 5 — Commission + Manual Payment-Status Override](features/phase-05-commission-payment-override.md) — ✅ **Done**
   (depends on Phase 1; independent of Phases 3–4)
6. [Phase 6 — End-of-Day Save, Backup, Restore — fixed Desktop path, no pickers](features/phase-06-backup-restore.md) — ✅ **Done**,
   **superseded by Phase 11** (depends on Phases 1–5 for final Excel column set and Arabic
   file/dialog text)
7. [Phase 7 — Arabic Status Labels (deal + payment)](features/phase-07-arabic-status-labels.md) — ✅ **Done**
   (depends on Phase 1; independent of Phases 2–6, but should land before Phase 6's Excel
   columns are next revised, since it changes what حالة الدفع / حالة العقد display everywhere
   including the export)
8. [Phase 8 — Deal Search (client + supplier, name + phone)](features/phase-08-deal-search.md) — ✅ **Done**
   (depends on Phase 2 for `suppliers.phone`, if not already present)
9. [Phase 9 — Live Analytics (auto-reflect deal changes)](features/phase-09-live-analytics.md) — ✅ **Done**
   (independent of Phases 7–8; touches the dashboard only)
10. [Phase 10 — Deal Edit Rules: Payments Preserved](features/phase-10-deal-edit-payments-preserved.md) — ✅ **Done**
    (depends on Phase 3's per-day rental-day payments; independent of Phases 7–9)
11. [Phase 11 — Backup & Restore: Two-Button Settings](features/phase-11-backup-restore-two-button.md) — ✅ **Done**
    (supersedes Phase 6; depends on Phases 1–5 for Excel column set and Arabic dialog text, same
    as Phase 6 did)
12. [Phase 12 — Expenses as a Dedicated Tab](features/phase-12-expenses-tab.md) — ✅ **Done**
    (independent; a pure navigation/UI promotion of the existing Expenses feature)
13. [Phase 13 — Expense Notes Visible in Analytics](features/phase-13-expense-notes-analytics.md) — ✅ **Done**
    (depends on Phase 12's Expenses tab existing as the source of truth for the note field the
    dashboard already stores)
14. [Phase 14 — Supplier Payments Shown in Expenses, Excluded from Net Profit](features/phase-14-supplier-payments-in-expenses.md) — ✅ **Done**
    (depends on Phase 12 for the Expenses tab to host the new read-only section)
15. [Phase 15 — Cars Tab (Fleet Registry)](features/phase-15-cars-tab.md) — ✅ **Done**
    (independent; reuses the existing `items` + `item_types` + `suppliers` schema)
16. [Phase 16 — Commission Reflects in Analytics Instantly](features/phase-16-commission-live-analytics.md) — ✅ **Done**
    (depends on Phase 5's commission mechanism and Phase 9's live-analytics refresh plumbing,
    both already shipped)
17. [Phase 17 — Deals List: Item-Led, No Deal Number](features/phase-17-deals-list-item-led.md) — ✅ **Done**
    (depends on Phase 15 for car display fields when the deal's item is a car; independent
    otherwise)
18. [Phase 18 — Expense Categories in Arabic](features/phase-18-arabic-expense-categories.md) — ✅ **Done**
    (independent; fixes the last English seed data)
19. [Phase 19 — Reset System (Settings)](features/phase-19-reset-system.md) — ✅ **Done**
    (independent)
20. [Phase 20 — Backup/Restore: Windows Hardening + Item Types in the Excel Restore](features/phase-20-backup-restore-windows-and-full-data.md) — ✅ **Done**
    (depends on Phase 11's backup/restore mechanism and Phase 15's items/item-types schema)
21. [Phase 21 — Supabase as Shared Online Database + Offline Badge](features/phase-21-supabase-cloud-sync.md) — ⏳ **Pending, open questions**
    (reverses the "offline-only" scope below; independent of Phases 1–20's Arabic/UX work)
22. [Phase 22 — Accounts Tab: Login, Register, User Action Log](features/phase-22-accounts-auth.md) — ⏳ **Pending, open questions**
    (depends on Phase 21's shared backend; reverses the "no accounts" scope below)

## Global Acceptance

- [ ] The app is 100% Arabic and RTL; no English string appears anywhere in the running UI;
      Western digits and EGP amounts render LTR embedded inside RTL Arabic text everywhere.
- [ ] Every money mutation (deal save, payment, refund, close/re-open, commission link) executes
      inside exactly one Drift transaction; a simulated crash mid-operation leaves the database
      in its pre-operation state, never a partial one.
- [ ] No phase introduces a stored "balance" field anywhere; every balance, receivable, and
      profit figure remains computed at read time from `transactions`, `transaction_items`,
      `payments`, `refunds`, `refund_items`, and `expenses`.
- [ ] In the car-deal form, تاريخ البدء + الوقت, تاريخ الانتهاء, and المده باليوم are always
      mutually consistent after any single edit to any one of them.
- [ ] Closing and re-opening a car line both work correctly and repeatedly: with
      `allowedKmPerDay` set, the extra-km charge is computed, added to the deal total on close,
      and fully voided (subtracted back out) on re-open; with `allowedKmPerDay` left null, no
      extra-km charge is ever computed or added, regardless of what kilometer values are
      entered.
- [ ] **Superseded by Phase 11** — this bullet described Phase 6's fixed-Desktop/no-picker
      design; see Phase 11's own acceptance criteria for the current two-button,
      admin-chosen-destination backup/restore behavior.
- [ ] Every operation that writes to SQLite, generates/writes an Excel file, or runs a backup,
      restore, or external copy shows the blocking progress overlay from start to finish, then a
      clear Arabic success or failure result. No disk-touching action ever returns silently.
- [ ] Every screen has been reviewed against the UX principles: fewer visible fields, advanced/
      optional fields collapsed, one dominant primary action, 48dp+ touch targets, and a
      plain-Arabic destructive-action confirmation naming the concrete consequence.
- [ ] Every status shown anywhere in the app is Arabic — مدفوع / جزئي / غير مدفوع for payment
      status, ساري / مغلق for a car line's contract status, ساري / مسترجع جزئياً / مسترجع بالكامل
      for a deal's own status — sourced from the shared chip widgets, never a screen-local
      string; digits and EGP amounts stay LTR embedded inside RTL text throughout.
- [ ] The deals search box matches a deal by client name, client phone, any line supplier's
      name, or any line supplier's phone; a multi-supplier deal is found by any one of its
      suppliers.
- [ ] Editing a deal always preserves its payments, including per-day rental-day payments on
      car lines; the only edit ever blocked is one that would shrink a car line's days below an
      already-paid day, and that block happens before any write, with the specified Arabic
      warning — never a silent deletion of payment history.
- [ ] The dashboard reflects every deal, payment, refund, and expense mutation automatically
      while it is open, with no stored/cached total anywhere and no manual refresh required.
- [ ] Every SQLite write, edit, or delete introduced by Phases 7–10 shows the existing blocking
      progress overlay from start to finish, then a clear Arabic success or failure result —
      the same rule every earlier phase's disk-touching actions already follow.
- [x] Settings shows exactly two data buttons: حفظ نسخة احتياطية (folder picker **or** a typed
      path, writes both `.sqlite` and `.xlsx`) and استرجاع البيانات (`.sqlite` → full restore;
      `.xlsx` → master-data-only import with an explicit Arabic disclaimer) — no other
      backup/restore/export tile remains in Settings.
- [x] المصروفات is its own side-nav tab with full expense CRUD; every expense's ملاحظات is
      visible from the dashboard without navigating to that tab; supplier payments are visible
      in a separate, read-only section of the Expenses tab but are never summed into the
      expenses total that feeds net profit; a commission change on any deal updates the
      dashboard's expenses/net-profit figures immediately, with no manual refresh.
- [x] السيارات is its own side-nav tab listing every car in the system with its assigned
      supplier, and supports adding a car and assigning it to a supplier directly.
- [x] The deals list shows the used item (car make/model + plate, or item label, plus a "+N"
      indicator for additional lines) per row instead of a deal number/id column; opening and
      searching deals is unaffected.
- [ ] All UI remains Arabic and RTL; digits and EGP amounts stay LTR-embedded; every disk/DB
      write introduced by Phases 11–17 shows the blocking progress overlay before a clear
      Arabic result; every money mutation stays atomic; every balance stays derived, never
      stored.
- [x] No expense category — seeded or admin-added — ever shows an English name out of the box;
      a pre-existing install's unrenamed English default categories are relabeled to Arabic in
      place, with zero disruption to expenses already linked to them.
- [x] Settings has an إعادة تعيين النظام button that wipes every client, supplier, item, deal,
      payment, refund, and expense (with a plain-Arabic destructive confirmation naming the
      consequence first) while preserving item types/fields and expense categories, needing no
      app restart afterward.
- [x] Backup/restore file operations tolerate transient Windows file-lock errors via a bounded
      retry instead of failing the whole operation on the first hit; the `.xlsx` restore also
      recreates item types and their field schemas, not just items, so a full catalog can be
      rebuilt from the Excel report alone when needed.

## Out of scope (entire revision)

- English UI or any language toggle — removed outright, not merely hidden.
- خزينة (cashbox) and عهدة (custody/float) sheets from the old Excel workbook.
- Cash-basis net profit as an alternative or additional reporting mode — net profit stays
  COGS-based (revenue − cost − expenses) everywhere; supplier-payment cash-out visibility
  (Phase 14) is a display-only addition, never a change to how profit is computed.

**No longer out of scope, as of Phase 21/22:** Supabase/online sync and multi-device live
sharing (Phase 21), and user accounts (Phase 22) — both bullets that previously excluded these
have been removed; see those phases for the current design and open questions. The `.sqlite`
full-replace restore flow (Phases 11/20) is unaffected and remains the local-backup mechanism
regardless of Phase 21's online sync.
