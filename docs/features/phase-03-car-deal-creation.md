# Phase 3 — Car Deal Creation: Days ↔ Dates ↔ Time (linked) — ✅ Done

[← Back to roadmap index](../FEATURES_ROADMAP.md)

## Goal
Make a new car deal's start date+time, end date, and day count a single mutually-consistent
trio instead of three independently-editable fields, and drop the generic per-line expiry date
for car lines in favor of the rental period itself.

## Depends on
Phase 1 (Arabic field labels, single-card layout for the rental fields).

## Schema deltas
No new columns — `transaction_items.rentStart`, `rentEnd`, `days`, `pricePerDay`, `costPerDay`,
`pickupKilometer` already exist. This phase changes **behavior**, not shape:

- `transaction_items.expiryDate` — still exists as a column (other item types may still use it),
  but the car-line editor no longer reads or writes it; a car line is created and edited with
  `expiryDate` left `NULL` going forward. No migration needed; existing car lines with a stale
  `expiryDate` are simply never shown or edited again once this phase ships.
- `rentStart` moves from a date-only field (as used today) to a full date **+ time** value —
  no schema change, since it is already a Drift `dateTime()` column; only the UI stops
  discarding the time-of-day component.

## State
- `provider/transaction_draft_provider.dart` / `DealLineInput` (`transactions_dao.dart`) — no
  new fields; the existing `rentStart`, `rentEnd`, `days` fields are kept in sync by the editor
  widget's own logic (see UI), the same "editable, override-tracked" pattern Phase 3 of the
  prior revision already established for `days` vs. rent dates — this phase generalizes that
  two-way binding to all three of start-datetime / end-date / days instead of days-follows-dates
  only.
- No cubit change: `commitDeal`/`editDeal` already persist whatever `rentStart`/`rentEnd`/`days`
  the draft carries.

## DAO / repo
No new queries. `DealLineInput.inclusiveDays(start, end)` (already added in the prior revision)
is reused as the shared conversion between a date range and a day count in both directions:

- days → end date: `end = start.add(Duration(days: days - 1))`
- end date → days: `days = DealLineInput.inclusiveDays(start, end)`

## UI
- `view/features/deals_features/widgets/deal_line_editor.dart` — for a car line, replace the
  separate rent-start/rent-end date pickers with one "بيانات الإيجار" card containing:
  - تاريخ البدء + الوقت (a combined date+time picker, exact local Egypt time)
  - المده باليوم (editable)
  - تاريخ الانتهاء (editable)
  - الكيلومتر (pickupKilometer)
  - السعر اليوم (pricePerDay), سعر المعرض (costPerDay)

  Two-way sync rule: editing المده باليوم recomputes تاريخ الانتهاء from the current start
  datetime; editing تاريخ الانتهاء recomputes المده باليوم; editing تاريخ البدء (date or time)
  keeps the currently-displayed المده باليوم and recomputes تاريخ الانتهاء from it (start moves,
  duration is preserved by default). A manual days override is still just "the last field the
  admin typed into" — there is no separate override flag to manage in this phase, since all
  three fields are now always mutually derived from whichever one was edited last, removing the
  keep/recompute conflict dialog the prior revision needed for a one-way (dates → days) sync.
- The expiry-date field in the same editor is hidden entirely when the line's item type is a
  car; it remains visible and editable for any other item type as today.

## Localization
New/changed labels: بيانات الإيجار (card title), الوقت (time field), replacing the previous
plain "Rent starts" / "Rent ends" / "Days" English labels from the prior revision with
تاريخ البدء, تاريخ الانتهاء, المده باليوم respectively (already listed in Phase 1's vocabulary).
RTL concern: the three-field row must lay out in reading order (right-to-left) and the time
picker's AM/PM or 24h rendering must stay LTR for the digits while its label is Arabic (e.g.
"4 مساءً" or "16:00" per whichever convention the time picker widget uses — pick one and apply
it consistently).

## Acceptance criteria
- [ ] Creating a car line and entering a start date+time plus a day count produces the correct
      end date (inclusive day count semantics, matching `DealLineInput.inclusiveDays`).
- [ ] Editing the end date on an existing car line recomputes the day count correctly.
- [ ] Editing the day count on an existing car line recomputes the end date correctly.
- [ ] Editing the start date or time preserves the current day count and shifts the end date
      accordingly.
- [ ] The three fields never disagree with each other after any single edit — there is no state
      where المده باليوم, تاريخ البدء, and تاريخ الانتهاء are mutually inconsistent.
- [ ] The start time is stored and redisplayed exactly (not silently zeroed to midnight).
- [ ] A car line's editor shows no expiry-date field; a non-car line's editor is unaffected and
      still shows it.
- [ ] `lineTotal` for a car line continues to equal `pricePerDay * days` (extra-km handled only
      at close, per Phase 4).

## Out of scope
- Time zones other than local Egypt time (no explicit UTC handling/conversion needed).
- Sub-day (hourly) pricing.
- Any change to non-car item types' date handling.
