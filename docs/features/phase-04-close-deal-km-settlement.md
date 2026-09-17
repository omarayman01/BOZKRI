# Phase 4 — Close Deal + Kilometer Settlement (re-openable) — ✅ Done

[← Back to roadmap index](../FEATURES_ROADMAP.md)

## Goal
Let a car line's kilometer allowance be genuinely optional (no allowance → no extra-km charge,
ever), compute the settlement correctly when an allowance is set, and make closing a car line a
reversible action rather than a one-way settlement.

## Depends on
Phase 3 (start datetime / days / pickup kilometer already captured at creation).

## Schema deltas
`transaction_items` — add:

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `allowedKmPerDay` | REAL | NULL | — | الكيلومترات المسموحة باليوم; **optional at creation** — NULL means the allowance feature is off for this line |
| `extraKmRate` | REAL | NULL | — | entered at close time, not at creation |
| `returnKilometer` | REAL | NULL | — | الكيلومتر المستلم, entered at close |
| `extraKmCharge` | REAL | NULL | — | settlement snapshot, fixed at close, cleared on re-open |
| `lineStatus` | TEXT | NOT NULL | `'active'` | `active` (ساري) \| `closed` (غير ساري) |

(`pickupKilometer` already exists from Phase 3 / the prior revision.)

Behavioral contract, not just a schema note — this is the core of the phase:

- `allowedKmPerDay == NULL` at the time of closing → the settlement is skipped entirely:
  `extraKm`, `extraKmRate`, `extraKmCharge` are never computed or written (stay `NULL`/0), no
  matter what `returnKilometer` is entered. Closing only records `returnKilometer` for the
  record and sets `lineStatus = closed`.
- `allowedKmPerDay != NULL` → run the full settlement:
  ```
  usedKm        = returnKilometer − pickupKilometer
  allowedTotal  = allowedKmPerDay * days
  extraKm       = max(0, usedKm − allowedTotal)
  extraKmCharge = extraKm * extraKmRate      // extraKmRate entered at close
  finalLineTotal = (pricePerDay * days) + extraKmCharge
  ```
- Re-opening a closed line: `lineStatus → active`, and `returnKilometer`, `extraKmRate`,
  `extraKmCharge` are all cleared back to `NULL` — the admin must re-enter them on the next
  close. `pickupKilometer`, `allowedKmPerDay`, `days`, `pricePerDay`, `costPerDay` are untouched
  by re-opening.
- Every close or re-open is one Drift transaction, and (per the existing pattern from the prior
  revision) a close's `extraKmCharge` is folded into the deal's `transactions.subtotal`/`total`
  so every derived balance keeps working without special-casing settled lines; a re-open must
  symmetrically **subtract** whatever `extraKmCharge` it is clearing from `subtotal`/`total`
  before nulling the column, so the deal's stored totals never drift from the sum of its lines.

## State
- `cubit/deals/deals_cubit.dart` — replace the prior one-way `settleReturn` with two calls:
  - `Future<bool> closeCarLine({required int transactionId, required int transactionItemId,
    required double returnKilometer, double? extraKmRate})` — `extraKmRate` required only when
    the line has `allowedKmPerDay` set; ignored otherwise.
  - `Future<bool> reopenCarLine({required int transactionId, required int transactionItemId})`
  Both reload the deal on success, same pattern as every other mutating cubit method here.

## DAO / repo
- `daos/transactions_dao.dart`:
  - `Future<TransactionItemRow?> getLineRow(int transactionItemId)` (already exists) — reused
    to read `allowedKmPerDay`/`pickupKilometer`/`days`/`pricePerDay` before computing a close.
  - `Future<void> closeCarLine({required int transactionItemId, required double
    returnKilometer, double? extraKmRate})` — one transaction: branches on whether
    `allowedKmPerDay` is null (record-only close) or not (full settlement + subtotal/total
    bump), sets `lineStatus = 'closed'`. Throws if the line is already closed.
  - `Future<void> reopenCarLine(int transactionItemId)` — one transaction: reads the line's
    current `extraKmCharge` (if any), subtracts it from the parent deal's `subtotal`/`total`,
    then clears `returnKilometer`/`extraKmRate`/`extraKmCharge` and sets
    `lineStatus = 'active'`. Throws if the line is already active.
- `repos/transactions_repo.dart` / `_impl.dart` — `closeCarLine`/`reopenCarLine` mirrored, with
  the pure km-math step (`usedKm`/`allowedTotal`/`extraKm`/`extraKmCharge`) kept in a
  side-effect-free calculator (e.g. `utils/return_settlement_calculator.dart`) so the close
  dialog can preview the numbers before the admin confirms, exactly as the prior revision's
  settlement dialog did.

## UI
- `view/features/deals_features/widgets/` — a close dialog for car lines:
  - If `allowedKmPerDay` is set: show pickup / received / used / allowed / extra / rate /
    charge / new total, all live as the admin types the received kilometer and the extra-km
    rate, before confirming.
  - If `allowedKmPerDay` is null: show only pickup / received kilometer and a plain sentence
    stating no extra-kilometer charge applies to this line.
  - A "إعادة فتح" (re-open) action on a closed line, gated behind its own confirmation dialog
    naming the consequence (the settlement will be cleared and must be re-entered).
- The car-line creation card (Phase 3) gains one more optional field:
  الكيلومترات المسموحة باليوم — left blank by default, grouped with the other advanced fields
  per Phase 1's collapsible-section rule.
- حالة العقد badge (ساري / غير ساري) on the line, already present from the prior revision,
  now also gates which of "إغلاق"/"إعادة فتح" is shown.

## Localization
New/changed labels: الكيلومترات المسموحة باليوم, الكيلومتر المستلم, كيلومتر إضافي,
سعر الكيلومتر الإضافي, رسوم الكيلومتر الإضافي, الإجمالي النهائي, إغلاق, إعادة فتح,
تأكيد إعادة الفتح, و"لا توجد رسوم كيلومتر إضافية لهذا العقد" (the no-allowance message). RTL
concern: the km math breakdown must read top-to-bottom with Arabic labels on the reading-order
leading edge (right) and numeric values LTR, verified in the Global Acceptance RTL check.

## Acceptance criteria
- [x] A car line created with `allowedKmPerDay` left blank can be closed with any received
      kilometer value, and `extraKmCharge` stays `0`/`NULL` and the deal total is unaffected.
- [x] A car line created with `allowedKmPerDay` set computes `usedKm`, `allowedTotal`,
      `extraKm` (clamped to zero), and `extraKmCharge` exactly per the formulas above, using the
      `extraKmRate` entered at close time (not at creation).
- [x] Closing sets `lineStatus = closed` (stored as `returned`, same badge/gating semantics) and
      folds `extraKmCharge` (if any) into the deal's `subtotal`/`total` in the same transaction;
      an exception anywhere in `closeCarLine` rolls the whole Drift transaction back, leaving the
      line fully `active` with no partial km fields set.
- [x] Re-opening a closed line sets `lineStatus = active`, clears `returnKilometer`/
      `extraKmRate`/`extraKmCharge`, and subtracts whatever `extraKmCharge` was in effect from
      the deal's `subtotal`/`total` — the deal's stored total always equals the sum of its
      lines' current `finalLineTotal` after any close/re-open sequence.
- [x] Re-opening then closing again (with the same or different received kilometer / rate)
      recomputes a fresh, correct settlement — no stale values leak from the previous close.
- [x] The close dialog shows the full km breakdown only when an allowance is set, and a plain
      "no extra charge" statement otherwise.

Implemented in `daos/transactions_dao.dart` (`closeCarLine`/`reopenCarLine`, replacing the old
one-way `applyReturnSettlement`), `repos/transactions_repo.dart`/`_impl.dart`,
`cubit/deals/deals_cubit.dart`, and `view/features/deals_features/widgets/return_settlement_dialog.dart`
(now a close dialog with an allowance-aware branch and rate entry at close time) plus a re-open
action gated by `ConfirmDialog` in `deal_detail_screen.dart`. `extraKmRate` was removed from the
line-creation UI (`deal_line_editor.dart`) since it is now entered only at close. Note:
`lineStatus` values remain `active`/`returned` (pre-existing enum), not literally
`active`/`closed` — functionally identical to the spec's contract.

## Out of scope
- Editing `allowedKmPerDay` itself after the line is created (it is set once at creation; only
  `returnKilometer`/`extraKmRate` are entered at close) — changing that would require its own
  explicit line-edit flow, not covered here.
- Fuel-level or damage-condition tracking at close.
- Automatic reminders for overdue returns.
