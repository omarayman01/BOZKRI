# Phase 7 — Arabic Status Labels (deal + payment) — ✅ Done

[← Back to roadmap index](../FEATURES_ROADMAP.md)

## Goal
Every status the app shows — a line's contract status and a deal's payment status — renders in
Arabic everywhere it appears, using one shared chip widget per status kind so the wording and
colors can never drift between screens.

## Depends on
Phase 1 (Arabic-only UI is already in place; this phase closes gaps Phase 1's string sweep
missed — local-variable string assignments rather than string literals passed straight to a
`label:`/`title:` parameter don't match a simple grep, and `payment_status_chip.dart` is exactly
that case).

## Schema deltas
None. Both statuses already exist as enums:
- `PaymentStatus` (`unpaid | partial | paid`) on `payment_model.dart` — already derived, never
  stored, computed by `TransactionWithItemsModel._status(owed, paid)` and equivalent per-line
  logic (`lineReceivableFor`).
- `LineStatus` (`active | returned`) on `transaction_item_model.dart`, added when car-return
  settlement shipped — already stored on `transaction_items.lineStatus`, driving the "Settle
  return" flow.

This phase does not rename either enum's Dart values (`unpaid|partial|paid`,
`active|returned`) or the stored `line_status` column values — only their **display** strings
change. Renaming the enum would touch every DB row and every switch statement for zero
behavioral gain; the spec's "closed = مغلق" requirement is satisfied by changing what `returned`
displays as, without touching what is stored.

## State
No new Cubit/Provider state. This is a presentation-layer fix: the chip widgets stop hardcoding
English and the few remaining raw-English call sites found by re-auditing the codebase are
corrected.

## DAO / repo
None — both statuses are already derived/read from existing queries.

## UI
- `view/core/widgets/payment_status_chip.dart` — `PaymentStatusChip`'s `paid`/`partial`/`unpaid`
  branches switch their `label` to مدفوع / جزئي / غير مدفوع respectively (currently 'Paid' /
  'Partial' / 'Unpaid'). Colors unchanged: مدفوع = green (`AppColors.success`), جزئي = amber
  (`AppColors.warning`), غير مدفوع = red (`AppColors.danger`).
- Same file, `DealStatusChip` (deal-level `TransactionStatus`: `active | partiallyRefunded |
  fullyRefunded`) — labels become ساري / مسترجع جزئياً / مسترجع بالكامل. This is a distinct
  status from the car line's حالة العقد below (a deal can be "ساري" while one of its car lines
  is "مغلق") — keep the two chips visually distinct as they already are (different color set).
- Car line status — everywhere `line.isReturned ? 'Returned' : 'Active'` (or the earlier
  Phase-4 wording "ساري"/"غير ساري") currently renders, switch to ساري (active) / مغلق
  (returned), per this phase's terminology. Known call sites to fix: the badge in
  `deal_line_editor.dart`'s per-day section, the badge in `line_item_tile.dart`, and any text in
  `return_settlement_dialog.dart` describing the line's post-settlement state. Colors: ساري =
  blue/teal (`AppColors.primary`/`secondary` family, matching the existing "active" tone),
  مغلق = grey (`AppColors.textSecondary`/`surface`).
- `view/core/navigation/app_routes.dart` and any other leftover English caught by re-running the
  Phase-1 audit grep (`Text\('[A-Z]`, `label = '[A-Z]` as a *variable assignment* rather than a
  named parameter, which the original sweep's regex did not match) get fixed as found; this
  phase's acceptance criterion is the outcome (no English status text), not a fixed file list.
- `utils/excel_export_helper.dart` — `_statusLabel`/`_contractStatusLabel` already emit
  مدفوع/مدفوع جزئياً/غير مدفوع and ساري/غير ساري; align `_contractStatusLabel`'s "غير ساري"
  output to مغلق for consistency with the in-app car-line wording introduced here (the deal-level
  `TransactionStatus` branch in that same helper is a separate concept and keeps its own
  wording).
- Dashboard, client detail, and supplier detail screens that already consume
  `PaymentStatusChip`/`DealStatusChip` need no code change — they inherit the new labels
  automatically by using the shared widget, which is the point of centralizing them here.

## Localization
No new l10n keys — these are structural chip labels, matching the existing convention that
this widget library uses plain Arabic string literals directly rather than `AppLocalizations`
(consistent with the rest of `view/core/widgets/`, none of which are l10n-driven). No RTL
concern beyond the standard chip layout already in use.

## Acceptance criteria
- [x] `PaymentStatusChip` shows مدفوع, جزئي, or غير مدفوع — never the English words — on every
      screen that renders it (deals list, deal detail, client detail, supplier detail,
      dashboard).
- [x] `DealStatusChip` shows ساري / مسترجع جزئياً / مسترجع بالكامل, never English.
- [x] Every car-line "حالة العقد" indicator (line editor, line detail tile, settlement dialog)
      shows ساري or مغلق, never "Active"/"Returned" or the earlier "غير ساري" wording.
- [x] Colors stay consistent across every place a given status renders, because every renderer
      goes through `PaymentStatusChip`/`DealStatusChip` — no screen paints its own ad hoc status
      pill.
- [x] The Excel export's حالة الدفع / حالة العقد columns use the same Arabic terms as the
      in-app chips (`_statusLabel`/`_contractStatusLabel`/the cars sheet's own
      `line.isReturned ? 'مغلق' : 'ساري'`).
- [x] A repeat of the Phase-1 audit grep (extended to catch local-variable string assignments,
      not just literal parameter values) finds zero remaining English status text anywhere in
      `lib/view/` (`grep -rnE "'(Paid|Unpaid|Partial|Active|Returned|Closed)'"` — no hits).

Verified against `payment_status_chip.dart` (`PaymentStatusChip`/`DealStatusChip`),
`line_item_tile.dart`, `deal_line_editor.dart`, and `excel_export_helper.dart` — all already
matched the spec exactly; no code changes were needed for this pass, only checking off the
criteria the "✅ Done" heading had left unchecked.

## Out of scope
- Changing what determines a status (thresholds, rounding) — this phase only changes display
  text, not the derivation logic in `TransactionWithItemsModel`/`TransactionItemModel`.
- The Phase-5 `paymentStatusOverride` mechanism itself (already Arabic since Phase 5 shipped) —
  this phase only guarantees the *derived* status chip is Arabic when no override is set.
