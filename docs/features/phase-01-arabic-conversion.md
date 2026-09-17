# Phase 1 — Full Arabic Conversion + UX Simplification — ✅ Done

[← Back to roadmap index](../FEATURES_ROADMAP.md)

## Goal
Make the entire app Arabic-only and RTL end to end, and simplify every screen to fewer visible
fields, one dominant primary action, and consistent large touch targets.

## Depends on
None (first phase).

## Schema deltas
None. This phase is UI/localization and layout only.

## State
- `provider/settings_provider.dart` — remove locale-toggle state and persistence
  (`prefsLocaleKey`, `toggleLocale()`, `setLocale()`); the provider still owns
  `expiryWarningDays` and other non-locale settings, but locale is no longer a runtime choice —
  `AppConstants.localeAr` becomes the fixed value baked into `MaterialApp`.
- No new Cubit needed.

## DAO / repo
None.

## UI
- `app.dart` — `MaterialApp.locale` fixed to `AppConstants.localeAr`,
  `supportedLocales = [AppConstants.localeAr]`, and the top-level `Directionality` in
  `AgencyApp.builder` fixed to `TextDirection.rtl` (no longer read from `SettingsProvider`).
- `view/features/settings_features/widgets/language_selector.dart` — deleted; its slot in
  `settings_screen.dart` removed.
- Every screen under `view/features/**` — string literals and `AppLocalizations` keys replaced
  with the Arabic vocabulary below; English literals (e.g. `'Qty'`, `'Unit cost'`, `'Settle
  return'` seen in `deal_line_editor.dart` / `return_settlement_dialog.dart` / others) replaced
  with their Arabic equivalents.
- Simplification pass per the UX principles, applied screen by screen:
  - `add_edit_deal_screen.dart` / `deal_line_editor.dart` — group Commission, payment-status
    override, and (from Phase 3/4) km/settlement fields under one collapsible "خيارات إضافية"
    section; the client picker + line items stay the single always-visible primary flow.
  - `add_edit_client_screen.dart` — group `passportId`/`nationalId` under a collapsible
    "بيانات الهوية" section (ties into Phase 2).
  - `settings_screen.dart` — one clearly primary action per card (e.g. "حفظ نهاية اليوم" as the
    dominant button; backup/restore/external-copy visually secondary).
  - Buttons and list rows across `view/core/widgets/` (`primary_button.dart`,
    `confirm_dialog.dart`, list rows in `deals_screen.dart`, `clients_screen.dart`,
    `suppliers_screen.dart`) sized to a minimum 48dp tap target with increased row padding.
  - `confirm_dialog.dart` call sites — every destructive action's `message`/`warning` rewritten
    in plain Arabic naming the concrete consequence (e.g. "سيتم حذف هذه الصفقة وكل الدفعات
    المرتبطة بها نهائياً" rather than a generic "are you sure").

## Localization
This phase retires the dual-locale system. `lib/l10n/app_ar.arb` becomes the single source of
truth for every UI string (fully populated); `lib/l10n/app_en.arb` is kept as a minimal stub so
`flutter gen-l10n` still runs, but no widget reads its values and it is not shown anywhere.

Core Arabic vocabulary to standardize on across screens (non-exhaustive — every screen's strings
follow this vocabulary rather than ad hoc phrasing):

العميل, المورد, الصفقة / الصفقات, ايجار الشقق, تذاكر الطيران, ايجار السيارات,
ماركة/موديل السيارة, مواصفات السيارة, رقم اللوحة, تاريخ البدء, تاريخ الانتهاء, المده باليوم,
الوقت, الكيلومتر, السعر اليوم, الاجمالي, المبلغ المدفوع, المتبقي, سعر المعرض, سعر المكتب,
صافي الربح باليوم, اجمالي صافي الربح, حالة الدفع, حالة العقد (ساري / غير ساري), العمولة,
طريقة الدفع (كاش / محفظة / انستاباي), التامين, ملاحظات, المصروفات, لوحة المعلومات,
رقم الموبايل, الرقم القومي, رقم جواز السفر.

RTL-specific concerns to verify (see Acceptance below): side-nav placement, deal-builder pane
order, `DataTable` column order in `deal_row.dart`/`item_row.dart`, dialog action-button order,
directional icons (back/forward, expand/collapse chevrons), and chart axis label alignment in
the dashboard — all must mirror correctly, while numeric/EGP values stay LTR-embedded as they
already do via `CurrencyFormatter`/`AppDateUtils`.

## Acceptance criteria
- [ ] No English string is visible anywhere in the running app (menus, dialogs, snackbars,
      tooltips, empty states, validation messages).
- [ ] The language selector is gone from Settings; there is no way to switch the app to English.
- [ ] `MaterialApp` always reports `Locale('ar')` and the whole app renders RTL, including a
      cold start with no prior `SharedPreferences` state.
- [ ] Side rail, deal-builder field order, table columns, dialog buttons, and directional icons
      all read correctly right-to-left.
- [ ] All money and date figures still render with Western digits, left-to-right, embedded
      inside RTL Arabic sentences (no digit mirroring, no reversed date order).
- [ ] Every screen has exactly one visually dominant primary action; optional/advanced fields
      (identity fields, commission, km/settlement) are collapsed by default.
- [ ] Every destructive confirmation dialog's message names the specific data that will be
      lost, in Arabic.

## Out of scope
- Any other language toggle or locale beyond Arabic.
- Redesigning the visual theme/branding (colors, typography) beyond RTL and label changes —
  covered separately by Phase 2's logo work.
- Changing navigation structure (still `MaterialApp` + `Navigator`, same routes).
