# Phase 17 — Deals List: Item-Led, No Deal Number

[← Back to roadmap index](../FEATURES_ROADMAP.md)

## Goal
The deals list stops leading with an internal deal number/id column and instead shows, per
deal, the item actually used — the car (make/model + plate) for a car deal, or the primary item
with a "+N" indicator for a multi-line deal — so the list reads the way the admin actually
thinks about a deal ("the Corolla rental", not "deal #47").

## Depends on
Phase 15 for car display fields (ماركة/موديل, رقم اللوحة) when a deal's item is a car;
otherwise independent — a non-car deal's "used item" is just its item label, already available
today.

## Schema deltas
None. Every field this phase displays already exists: `transaction_items.itemId` →
`items.label` (and, for cars, the Car item type's dynamic fields already surfaced via
`TransactionItemModel.itemLabel` and the item's own field values).

## State
- `model/transaction_with_items_model.dart` — a new getter, `TransactionItemModel get
  primaryItem` (the first line, by whatever ordering `items` already uses — insertion order is
  fine, consistent with how `deal.items.first` would already behave) and `int get
  additionalItemCount` (`items.length - 1`, `0` for a single-line deal) — both pure derivations
  over the already-loaded `items` list, no new query.
- `cubit/deals/deals_cubit.dart`/`deals_state.dart` — unchanged; `visibleDeals` and the
  underlying `getAllDeals` already load every line per deal, which is all this phase needs.

## DAO / repo
No new queries — `TransactionsDao.getAllDeals`/`_linesFor` already load every line (including,
for a car line, its item label) with the deal; this phase only changes what the list *displays*
from data it already has.

## UI
- `view/features/deals_features/widgets/deal_row.dart` — the "الصفقة" column (`#${deal.id}`)
  is removed entirely. In its place (or reusing the same column position), a new cell shows
  `deal.primaryItem.itemLabel` — for a car line specifically, prefer showing make/model + plate
  if the Car item type's dynamic fields expose them directly on `TransactionItemModel` (via the
  same field-value join Phase 15 introduces for the Cars tab), falling back to the plain item
  label otherwise — plus, when `deal.additionalItemCount > 0`, a trailing "+N" badge (e.g.
  "تويوتا كورولا +2").
- `view/features/deals_features/deal_detail_screen.dart` — may still show the deal's internal
  id somewhere for support/reference purposes (e.g. a small caption near the header), but the
  **list** no longer leads with or exposes it as a primary column.
- Row selection (`DataRow.onSelectChanged` → open detail) is unchanged — a deal opens by tapping
  its row, never by typing or matching a visible number, so removing the number column does not
  remove any way of reaching a deal.
- `deals_screen.dart`'s search (Phase 8) still matches by deal id when the admin types a numeric
  query — that matching logic is unaffected by removing the id from the *displayed* columns.

## Localization
No new labels beyond whatever the Cars tab (Phase 15) already introduces for make/model/plate;
the "+N" indicator is a plain digit suffix, LTR-embedded like every other digit in this app.

## Acceptance criteria
- [ ] The deals list no longer shows a deal-number/id column anywhere.
- [ ] Each deal row shows its used item — for a car deal, make/model + plate when those fields
      are available on the line, otherwise the item label; for any other deal type, the item
      label.
- [ ] A multi-line deal's row shows its primary item plus a "+N" indicator for the remaining
      line count; a single-line deal shows no "+N" indicator.
- [ ] Opening a deal (tapping its row) continues to work exactly as before; searching by deal id
      (Phase 8) continues to work even though the id is no longer a visible column.
- [ ] No other screen that already displays a deal id (deal detail, payment/refund history,
      Excel export) is affected — this phase only changes the deals **list**'s columns.

## Out of scope
- Removing the deal id from `deal_detail_screen.dart`, the Excel export, or anywhere else it is
  useful for support/reference — only the list's leading column changes.
- Reordering multi-line items or letting the admin choose which line is "primary" — the first
  line, by existing load order, is always shown.
