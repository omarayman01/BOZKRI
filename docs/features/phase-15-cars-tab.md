# Phase 15 — Cars Tab (Fleet Registry)

[← Back to roadmap index](../FEATURES_ROADMAP.md)

## Goal
Give the admin one place to see every car the agency has ever entered into the system —
regardless of which deals it has been used in — along with its assigned supplier, and to add a
new car and assign it to a supplier directly, without going through a deal.

## Depends on
None functionally; reuses the existing `items` / `item_types` / `suppliers` schema and their
existing repos.

## Schema deltas
None. A car is already representable as an `items` row with `itemTypeId` pointing at the Car
item type and `supplierId` set — both columns already exist and are already required (non-null)
on every item. This phase adds no column; it is a filtered view + a creation/assignment UI over
data that already fits the existing shape.

## State
- Either a new `cubit/cars/cars_cubit.dart` + `cars_state.dart` scoped to items where
  `itemTypeId` resolves to the Car type, or a thin wrapper around the existing
  `cubit/items/items_cubit.dart` (whichever the existing `ItemsCubit` API makes cheaper) —
  the choice is an implementation detail; the requirement is a list scoped to cars only, each
  entry carrying its assigned supplier's name.
- No new Provider — the existing `ItemsCacheProvider`/`SuppliersCacheProvider` pattern already
  used by the deal builder's item/supplier pickers is reused for the "assign to supplier"
  picker on this new screen.

## DAO / repo
- `daos/items_dao.dart` — `getCarsWithSupplier()` (or a `WHERE item_type = Car` variant of
  whatever `getItems()` already does) — a `SELECT` joining `items` to `suppliers` and to the Car
  item type's `item_type_fields`/`item_field_values` so ماركة/موديل, رقم اللوحة, مواصفات (or
  whichever dynamic fields the Car item type is configured with) come back alongside each car
  and its supplier's name in one query, mirroring how `_linesFor`/`getAllDeals` already join
  supplier names onto their rows.
- `repos/items_repo.dart` — a matching `getCarsWithSupplier()`/`addCar(...)` surface; `addCar`
  is not a new write path — it is `ItemsRepo.addItem` (already existing) called with the Car
  item type and a chosen `supplierId`, so no new DAO write method is strictly required beyond
  the read-side join above.

## UI
- `view/features/cars_features/cars_screen.dart` (new) — a dense RTL table: ماركة/موديل, رقم
  اللوحة, مواصفات (or whatever the Car item type's configured dynamic fields are — this screen
  does not hardcode car-specific columns beyond what `item_type_fields` already defines), المورد
  (supplier name), وضع النشاط (active/inactive), one dominant "إضافة سيارة" primary action.
- `view/features/cars_features/add_edit_car_screen.dart` (new) — the Car item type's existing
  dynamic-field form (same `dynamic_fields_form.dart` machinery `add_edit_item_screen.dart`
  already uses for every item type) plus a searchable supplier picker (reusing
  `party_picker.dart`'s existing supplier-search pattern) to set `supplierId`. Editing an
  existing car reuses the same screen; deactivating reuses the existing `isActive` toggle every
  item already has.
- `view/features/cars_features/widgets/car_row.dart` (new) — one row's cells, mirroring
  `deal_row.dart`/`expense_row.dart`'s per-column `DataCell` pattern.
- `view/core/navigation/main_shell.dart` / `app_routes.dart` — new side-nav destination
  "السيارات" in the RTL order given in Phase 12's State section, wired the same way every other
  primary tab is.
- A newly added car must appear immediately (no app restart, no manual refresh) in both this
  tab's list and the deal builder's car/item picker, since both read from the same `items`
  table through the same cache Provider the deal builder already uses.

## Localization
New labels: السيارات (nav item + tab title), إضافة سيارة, وضع النشاط. Field labels for ماركة/
موديل السيارة, رقم اللوحة, مواصفات السيارة already exist in Phase 1's vocabulary if the Car item
type is already configured with those exact dynamic fields; if not, whatever fields the admin
has configured for Car in Settings' item-type manager are used as-is — this phase does not
change item-type configuration.

## Acceptance criteria
- [ ] Every car item in the system (every `items` row of the Car item type) appears in the Cars
      tab, each showing its assigned supplier's name.
- [ ] Adding a new car and assigning it to a chosen (searchable) supplier succeeds and the car
      appears immediately in the Cars tab.
- [ ] The newly added car is immediately selectable in the deal builder's car/item picker,
      with no app restart or manual cache refresh.
- [ ] Editing a car's fields or its assigned supplier updates the same underlying `items` row
      (no duplicate row created); deactivating a car hides it from the deal builder's picker the
      same way deactivating any other item already does.
- [ ] The Cars tab shows only Car-item-type rows — it never lists apartments, flights, or any
      other item type.

## Out of scope
- A car-specific schema (VIN, insurance expiry, maintenance log, etc.) beyond whatever dynamic
  fields the Car item type is already configured with — any new field goes through the existing
  item-type field editor in Settings, not a new column.
- Fleet utilization/availability calendars.
