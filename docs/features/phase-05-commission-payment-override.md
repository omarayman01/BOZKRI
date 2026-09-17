# Phase 5 — Commission + Manual Payment-Status Override — ✅ Done

[← Back to roadmap index](../FEATURES_ROADMAP.md)

## Goal
Let a deal optionally record a commission that flows into profit via the existing expense
system, and let the admin override the *displayed* payment status without altering how money is
actually computed.

## Depends on
Phase 1 (Arabic labels, collapsible "خيارات إضافية" placement). Independent of Phases 3–4.

## Schema deltas
`transactions` — add:

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `commissionName` | TEXT | NULL | — | العمولة - الاسم, free-text label |
| `commissionAmount` | REAL | NULL | — | if set and > 0, drives a linked expense |
| `paymentStatusOverride` | TEXT | NULL | — | `paid` (مدفوع) \| `unpaid` (غير مدفوع); NULL = use derived status; **display only** |

No new column on `expenses` — the link is the existing `expenses.transactionId` FK plus a
`category` row named "عمولة" and an `amount = commissionAmount` expense row.

## State
- `cubit/deals/deals_cubit.dart` (via `commitDeal`/`editDeal`) — when `commissionAmount` is set
  (non-null and > 0) on save, upsert a linked expense (`expenses.transactionId = deal.id`,
  category "عمولة", `amount = commissionAmount`, `note = commissionName`) inside the same Drift
  transaction as the deal save; when cleared or set to `0`, delete the linked expense.
- `provider/transaction_draft_provider.dart` — `commissionName`, `commissionAmount`,
  `paymentStatusOverride` added to the draft, loaded from and saved back to the deal exactly
  like `discount`/`notes` today.
- Deal deletion relies on the existing `expenses.transactionId` cascade, so the linked
  commission expense is removed automatically with the deal — no extra code needed there.

## DAO / repo
- `daos/expenses_dao.dart` — a get-or-create lookup for the "عمولة" category (by name), and an
  upsert/delete keyed on `(transactionId, categoryId)` rather than on the expense title, so it
  is robust to the linked expense being renamed.
- `daos/transactions_dao.dart` — `commitDeal`/`editDeal` extended with optional
  `commissionName`, `commissionAmount`, `paymentStatusOverride` params, persisted on the
  `transactions` row and used to drive the expense sync above.
- `repos/transactions_repo.dart` — a pure `resolveDisplayedPaymentStatus(TransactionModel deal,
  ...)` (or a `displayedClientStatus` getter alongside the existing derived `clientStatus`)
  returning `deal.paymentStatusOverride` if non-null, else the existing derived-from-payments
  logic, unchanged. Validation: `commissionAmount` cannot be negative; `paymentStatusOverride`
  can only be مدفوع or غير مدفوع, never the derived "partial" state.

## UI
- `view/features/deals_features/widgets/deal_line_editor.dart` / the deal form's "خيارات
  إضافية" collapsible section — commission name/amount fields and a
  تلقائي (مشتق) / مدفوع / غير مدفوع status-override selector, alongside the existing discount
  field.
- `view/features/deals_features/deal_detail_screen.dart` — shows العمولة (name + amount) when
  set, and حالة الدفع using the displayed (override-aware) status, with a small "(يدوي)" tag
  when it is manually overridden so the admin never confuses it with the real derived state.

## Localization
New labels: العمولة, اسم العمولة, مبلغ العمولة, حالة الدفع (يدوي), تلقائي (مشتق), مدفوع,
غير مدفوع. No RTL-specific layout beyond the standard label/value pairing already used
elsewhere in the deal form.

## Acceptance criteria
- [x] Setting `commissionAmount` on a deal creates exactly one linked expense in the "عمولة"
      category with the correct amount and name.
- [x] Editing `commissionAmount` updates that same linked expense in place — no duplicate rows.
- [x] Clearing or zeroing `commissionAmount` deletes the linked expense.
- [x] Deleting the deal deletes its linked commission expense.
- [x] Net-profit reporting that already aggregates expenses reflects the commission
      automatically, with no separate commission-specific aggregation logic.
- [x] Setting `paymentStatusOverride` changes only the *displayed* حالة الدفع; every money
      calculation (balances, receivables, profit) continues to use actual `payments` and is
      unaffected by the override.
- [x] `paymentStatusOverride = NULL` (default) always falls back to the derived status.
- [x] The UI visibly distinguishes an overridden status from a derived one.

Verified against `daos/transactions_dao.dart` (`_syncCommissionExpense`),
`repos/transactions_repo_impl.dart` (validation), `model/transaction_with_items_model.dart`
(`displayedClientStatus`/`hasClientStatusOverride`), and the deal form/detail screens — all
matched the spec. One bug fixed: the linked expense category was hardcoded as the English
`'Commission'` instead of `"عمولة"` (`transactions_dao.dart`), inconsistent with Phase 1's
Arabic-only requirement.

## Out of scope
- Commission on suppliers/expenses unrelated to a deal.
- Automatic commission calculation (always manually entered).
- History/audit trail of override changes.
