# Phase 8 — Deal Search (client + supplier, name + phone) — ✅ Done

[← Back to roadmap index](../FEATURES_ROADMAP.md)

## Goal
The deals screen's search box matches a deal by its client's name or phone, or by the name or
phone of *any* supplier on any of its lines — not just client name as today.

## Depends on
Phase 2 for `suppliers.phone` — already present in the schema (`Suppliers.phone` has existed
since before this roadmap; Phase 2 does not need to add it). No new phase dependency in
practice, listed for completeness in case Phase 2 ships later than Phase 8.

## Schema deltas
None. `clients.phone` and `suppliers.phone` both already exist as nullable `TEXT` columns.

## State
- `cubit/deals/deals_state.dart` — `DealsState.visibleDeals` (the existing in-memory filter,
  the same pattern `ClientsState.visibleClients` already uses for its own search) extended to
  match against client phone and every line's supplier phone, not just client/supplier name and
  deal id as today. This keeps the established architecture — `DealsCubit.loadDeals()` already
  loads every deal with its lines and client name up front; search stays a pure client-side
  filter over that already-loaded list rather than a new round-trip query, consistent with how
  every other list screen (`clients_screen.dart`, `suppliers_screen.dart`) already searches.
- No new Cubit method — `DealsCubit.search(String query)` already exists and only updates
  `state.query`; `visibleDeals` does the matching.

## DAO / repo
- `daos/transactions_dao.dart` — `getAllDeals`/`getDeal`'s existing joined queries gain two more
  selected columns so the phone numbers are available to filter on without an extra query:
  - The top-level deal query (`SELECT t.*, c.name AS client_name FROM transactions t JOIN
    clients c ...`) adds `c.phone AS client_phone`.
  - `_linesFor` (`SELECT ti.*, i.label AS item_label, ... s.name AS supplier_name FROM
    transaction_items ti ... JOIN suppliers s ...`) adds `s.phone AS supplier_phone`.
- `mappers.dart` — `TransactionRowMapper.toModel`/`TransactionItemRowMapper.toModel` gain
  optional `clientPhone`/`supplierPhone` parameters, populated from those new columns, mirroring
  how `clientName`/`supplierName` are already threaded through.
- `model/transaction_model.dart` / `model/transaction_item_model.dart` — add `clientPhone`
  (on `TransactionModel`) and `supplierPhone` (on `TransactionItemModel`), both nullable
  `String?`, alongside the existing `clientName`/`supplierName` fields — same shape, not stored
  columns, populated only by the join above.
- This is a deliberate departure from a dedicated `searchDeals(query)` SQL method: the deals
  list is already fully materialized client-side (same as clients/suppliers), so adding a
  second, SQL-driven search path would create two divergent ways to filter the same data.
  Extending the existing join + existing in-memory filter reaches the identical result with one
  code path, matching how every other list screen already searches.

## UI
No new widget — the search field already exists above the deals table
(`deals_screen.dart`, wired to `DealsCubit.search`); it needs no visible change, only the
underlying match to widen. Empty-state message when a query matches nothing already exists via
the shared list-screen empty state; no change needed there either.

## Localization
No new strings — the search field's placeholder/label is already Arabic from Phase 1; no
additional Arabic text is introduced by widening what it matches.

## Acceptance criteria
- [x] Searching by the client's exact or partial name returns every deal for that client (as
      today — unchanged).
- [x] Searching by the client's phone number (رقم الموبايل), with or without spaces/dashes in
      either the stored number or the typed query, returns that client's deals.
- [x] Searching by a supplier's name returns every deal that has at least one line from that
      supplier (as today — unchanged).
- [x] Searching by a supplier's phone number returns every deal that has at least one line from
      a supplier with that phone.
- [x] A deal with lines from two different suppliers is found by searching either supplier's
      name or phone.
- [x] The match is case-insensitive and trims leading/trailing whitespace, matching the
      existing `ClientsState.visibleClients` convention; phone matching additionally strips
      spaces and dashes from both the stored number and the query before comparing, so
      `010-123-4567` and `0101234567` are treated as the same number.
- [x] Searching by deal id (already supported) continues to work unchanged.

Implemented in `model/transaction_model.dart`/`model/transaction_item_model.dart` (new
`clientPhone`/`supplierPhone` fields), `model/transaction_with_items_model.dart` (new
`supplierPhones` getter alongside `supplierNames`), `mappers.dart` (both row mappers thread the
new phone params through), `daos/transactions_dao.dart` (`getAllDeals`/`getDeal`/`_linesFor`'s
joins now select `c.phone AS client_phone` / `s.phone AS supplier_phone`), and
`cubit/deals/deals_state.dart` (`visibleDeals` matches client/supplier phone with a shared
`_normalizePhone` helper that strips spaces and dashes before comparing). No SQL-driven search
path was added — extends the existing client-side filter, per the spec's explicit "one code
path" design note. Regenerated freezed models via `flutter pub run build_runner build
--delete-conflicting-outputs`.

## Out of scope
- Fuzzy/typo-tolerant matching — exact substring match only, same as every other search in the
  app.
- Searching by anything other than client/supplier name/phone (item labels, notes, amounts) —
  not requested, not added.
