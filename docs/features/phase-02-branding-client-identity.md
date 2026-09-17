# Phase 2 — Branding + Client Identity Fields — ✅ Done

[← Back to roadmap index](../FEATURES_ROADMAP.md)

## Goal
Apply the BOZKRI logo across the app and let clients optionally carry a national ID / passport
number for identification and search, tucked under a collapsible section per Phase 1's UX rule.

## Depends on
Phase 1 (Arabic labels for the two new fields; the collapsible-section pattern).

## Schema deltas
`clients` table — add:

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `nationalId` | TEXT | NULL | — | الرقم القومي, optional |
| `passportId` | TEXT | NULL | — | رقم جواز السفر, optional |

No FK, no uniqueness constraint, no format validation.

## State
- `cubit/clients/clients_cubit.dart` — `addClient`/create path extended with optional
  `nationalId`, `passportId`.
- `cubit/clients/client_detail_cubit.dart` — no new responsibility beyond surfacing the two
  fields already present on the loaded `ClientModel`.
- A shared `BrandingAsset` accessor (constant path + graceful fallback icon when the asset file
  is absent) referenced from the side-nav header Provider-driven theme, not a new Provider.

## DAO / repo
- `daos/clients_dao.dart` — insert/update statements extended with `nationalId`, `passportId`.
- `repos/clients_repo.dart` / `_impl.dart` — `addClient` gains optional `nationalId`,
  `passportId` params; `searchClients`/in-memory filter (`ClientsState.visibleClients`) extended
  to match either ID field, and the deal-builder client picker (`party_picker.dart`) extended
  the same way, exactly as already established for the existing name/phone search.

## UI
- `view/features/clients_features/add_edit_client_screen.dart` — two new optional fields
  (الرقم القومي, رقم جواز السفر) inside a collapsible "بيانات الهوية" group, collapsed by
  default per Phase 1.
- `view/features/clients_features/client_detail_screen.dart` — display الرقم القومي /
  رقم جواز السفر only when present.
- App logo asset (`assets/branding/app_logo.<ext>`) wired into: app icon (macOS/Windows icon
  generation), side-nav header, splash screen, and the Excel export header banner (Phase 6).

## Localization
New Arabic labels: الرقم القومي, رقم جواز السفر, بيانات الهوية (section header), plus a hint
string for each field ("اختياري"). No RTL-specific concern beyond the standard label/value
pairing already used for phone.

## Acceptance criteria
- [ ] Creating or editing a client with only one of the two ID fields, or neither, is allowed
      and saves correctly.
- [ ] Client detail view shows الرقم القومي / رقم جواز السفر only when non-null.
- [ ] Client search (list screen and the deal-builder client picker) returns a match when the
      search text equals or is contained in either ID field.
- [ ] App icon, splash, side-nav header, and Excel report header all show the BOZKRI logo on
      both macOS and Windows builds; the app still runs and shows a sane fallback if the asset
      file is missing.

## Out of scope
- ID format validation/checksums.
- Uniqueness constraints on either ID field.
- OCR or scanning of ID documents.
