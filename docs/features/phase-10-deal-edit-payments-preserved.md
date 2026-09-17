# Phase 10 — Deal Edit Rules: Payments Preserved — ✅ Done

[← Back to roadmap index](../FEATURES_ROADMAP.md)

## Goal
Editing a deal never resets, deletes, or orphans its payments — including per-day rental-day
payments on car lines — and payment status simply recomputes from whatever payments survive the
edit.

## Depends on
Phase 3 (per-day rental-day payments, `payments.transactionItemId`/`rentalDayDate`), since the
sharpest version of the bug this phase fixes is specific to car lines.

## Current bug (why this phase is needed)
`TransactionsDao.editDeal` currently does, inside its one transaction: delete every row in
`refunds` for the deal, **delete every row in `transaction_items` for the deal**, then re-insert
a fresh set of lines from the submitted `DealLineInput`s via `_insertLines` (new autoincrement
`id`s). `payments.transaction_item_id` has `onDelete: KeyAction.cascade`. So today, **any** edit
to a deal that has per-day rental payments recorded on it silently deletes every one of those
payment rows, because the lines they reference are deleted and recreated with new ids — even
when the edit doesn't touch that line at all. This phase replaces that delete-all/reinsert
behavior with an update-in-place-when-possible strategy so line identity — and therefore the
payments that reference it — survives an edit.

## Schema deltas
None. No new columns. The fix is in `editDeal`'s write strategy, not the schema.

## State
- `provider/transaction_draft_provider.dart` / `DealLineInput` (`transactions_dao.dart`) — add
  an optional `existingLineId` (`int?`), populated from `TransactionItemModel.id` when
  `loadForEdit` builds the draft's lines from a loaded deal, and left `null` for any line the
  admin adds fresh during the edit. This is the identity key `editDeal` uses to tell "this is
  the same line, just changed" from "this line is new" or "this line was removed."
- `cubit/deals/deals_cubit.dart` — `editDeal` surfaces the new blocking-constraint failure
  (see DAO below) through the same `errorMessage` path every other validation failure already
  uses, so the existing error-snackbar UI needs no new plumbing.

## DAO / repo
- `daos/transactions_dao.dart` — `editDeal` rewritten to diff by `existingLineId` instead of
  delete-all/reinsert:
  - Lines in the submitted set with a non-null `existingLineId` that still exists on the deal:
    `UPDATE transaction_items ... WHERE id = existingLineId` with every field the line editor
    can change (item, supplier, qty/unitCost/unitPrice, rent dates, per-day/km fields) — the row
    **id is preserved**, so any `payments` referencing it via `transaction_item_id` stay valid.
  - Lines with `existingLineId` values that no longer appear in the submitted set: deleted (as
    today) — this is a real removal, and cascading away that line's own per-day payments is
    correct, since the line itself is gone.
  - Lines with `existingLineId == null`: inserted as new rows (as `_insertLines` already does).
  - `refunds` for the deal are still cleared on edit, unchanged from today (refunds reference
    `transaction_item_id` too, and a full re-edit already cannot guarantee old refund lines
    still make sense — this phase does not change that existing, separate behavior).
- **New pre-write validation, inside the same transaction, before any write commits**: for every
  updated line whose `days` is being reduced, check whether any `payments` row with that line's
  `transaction_item_id` has a `rental_day_date` falling outside the new
  `[rentStart, rentStart + newDays)` window. If any exist, throw a `ConstraintFailure` carrying
  the Arabic message:
  `تحذير: توجد أيام مدفوعة خارج المدة الجديدة — الغِ تحديد تلك الأيام أولاً قبل تقليل المدة.`
  — the whole edit transaction rolls back; nothing is written, no payment row is touched.
- Extending days: no validation needed — the newly-added days simply have no matching payment
  row yet, so `PerDayRentalGrid`'s existing derivation (`paidDaysFor`/`unpaidDaysFor`) already
  shows them as unpaid without any code change there.
- Changing `pricePerDay`/`costPerDay` on a line with existing payments: no validation needed —
  `lineTotal`/`finalLineTotal` recompute from the new price, existing payment rows are untouched
  (a day already marked paid keeps the amount recorded on its own payment row, per the existing,
  unchanged `markRentalDayPaid` design — a payment amount is a historical fact, not re-derived).
- `repos/transactions_repo.dart`/`_impl.dart` — `editDeal` unchanged in signature; the new
  constraint surfaces through the same `Failure`-catching `guard()` pattern every other
  validation already uses.

## UI
- `view/features/deals_features/add_edit_deal_screen.dart` — no structural change; the existing
  error-snackbar path (`_showError`, already wired to `cubit.state.errorMessage`) displays the
  new Arabic blocking message unchanged, since it already renders whatever
  `DealsCubit.state.errorMessage` holds.
- `view/features/deals_features/widgets/deal_line_editor.dart` — no change required for the
  block itself (it surfaces on save, not while typing), though the admin's fastest path to
  resolving it is to open the deal's `PerDayRentalGrid` and unmark the offending days before
  retrying the edit — worth a one-line hint in the error snackbar or a follow-on dialog, at the
  implementer's discretion, but not required by this spec.

## Localization
The one new string is given verbatim above. No other new strings.

## Acceptance criteria
- [x] Editing any field on a deal that has per-day rental payments recorded, without reducing
      any line's `days` below its paid days, leaves every one of those payment rows intact —
      the line keeps its `transaction_items.id`, so `payments.transaction_item_id` is never
      touched for an updated-in-place line.
- [x] Payment status (`حالة الدفع`) after such an edit recomputes correctly from the surviving
      payments and the (possibly changed) line total — unchanged, since `displayedClientStatus`
      was already derived at read time and this phase touches no derivation logic.
- [x] Reducing a car line's `days` such that at least one already-paid rental day would fall
      outside the new range is blocked before any write occurs (`_assertPaidDaysWithinNewRange`
      runs before any write in the transaction), showing exactly the specified Arabic message;
      the deal's stored data is unchanged after a blocked attempt since the whole transaction
      throws and rolls back.
- [x] Reducing `days` when no paid day falls outside the new range succeeds normally.
- [x] Extending a car line's `days` succeeds; the newly available days show as unpaid (no code
      change needed — `PerDayRentalGrid` already derives paid/unpaid from `payments` rows, and
      extending adds no new payment row); existing paid days are unaffected.
- [x] Deleting a line entirely from a deal (not just shrinking it) still deletes that line's own
      payments via the existing cascade — lines whose `existingLineId` disappears from the
      submitted set are still hard-deleted, unchanged from before.
- [x] A simulated crash mid-edit-transaction leaves the deal, its lines, and its payments in
      their pre-edit state — the whole method still runs inside one `transaction(() async {...})`
      block, unchanged.

Implemented in `daos/transactions_dao.dart`: `DealLineInput` gained `existingLineId` (threaded
through `copyWith`); `editDeal` now diffs submitted lines against the existing rows by that id —
matched lines are `UPDATE`d in place (preserving `payments.transaction_item_id`), lines whose id
disappeared are deleted (correctly cascading their own payments), and lines with no
`existingLineId` are inserted as before via `_insertLines`. A new
`_assertPaidDaysWithinNewRange` helper runs before any write and throws the specified Arabic
`ConstraintFailure` if shrinking a line's `days` would strand a paid rental day outside the new
window. `transaction_draft_provider.dart`'s `loadForEdit` now populates `existingLineId: l.id`
from each loaded `TransactionItemModel`. `deals_cubit.dart`/`repos/transactions_repo.dart` needed
no changes — the new failure surfaces through the existing generic `Failure`-catching path, as
the spec anticipated.

## Out of scope
- Changing how refunds behave on edit (refunds are still cleared on any edit, as today) — only
  payments are brought under the "preserved" guarantee by this phase.
- Any UI to preview which specific paid days are blocking a shrink before the save attempt is
  made — the block is discovered on save, per the spec above.
