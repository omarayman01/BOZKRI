# Phase 14 — Supplier Payments Shown in Expenses, Excluded from Net Profit

[← Back to roadmap index](../FEATURES_ROADMAP.md)

## Goal
Give the admin cash-out visibility into supplier payments from inside the Expenses tab, as a
clearly separate, read-only section — without ever letting those payments be double-counted
against net profit, since the cost they settle is already counted once as COGS.

## Depends on
Phase 12 (the Expenses tab is where this new read-only section is hosted).

## Schema deltas
None. `payments` (party = `supplier`) already carries everything this section needs: date,
amount, method, `supplierId`, `transactionId`.

## State
- `cubit/expenses/expenses_cubit.dart` — gains a sibling read method,
  `Future<List<PaymentModel>> loadSupplierPayments({AppDateRange? range})` (or a small dedicated
  `SupplierPaymentsCubit` if keeping `ExpensesCubit` scoped strictly to `expenses` rows is
  preferred) — reads `payments` where `party = 'supplier'` for the selected range, joined to
  supplier name and the deal's client name for context.
- No change to `TransactionWithItemsModel`/`DashboardSummaryModel`'s profit math — this phase
  adds a **new, separate** read path; it does not touch `netCost`/`netProfit`'s existing
  derivation, which already comes from `transactions.totalCost` (COGS snapshots) net of
  refunded cost, never from `payments`.

## DAO / repo
- `daos/payments_dao.dart` (or `expenses_dao.dart`) — `getSupplierPayments({DateTime? from,
  DateTime? to})` — a `SELECT` over `payments JOIN suppliers JOIN transactions` filtered to
  `party = 'supplier' AND voided = 0`, for the given date range, returning supplier name, deal
  id, method, amount, date.
- No change anywhere that already computes net profit
  (`TransactionWithItemsModel.netProfit`, `DashboardDao.getSummary`'s revenue/cost aggregates) —
  this phase deliberately does not touch that code path, precisely to guarantee no double-count.

## UI
- `view/features/expenses_features/expenses_screen.dart` — a second, visually distinct,
  read-only section titled "مدفوعات الموردين" below the expenses list: date, supplier, deal
  (linking to `deal_detail_screen.dart`, consistent with every other place a deal reference
  appears in this app), method, amount. No add/edit/delete controls here — these rows are a
  view onto `payments`, not a separate ledger; they are recorded from the deal detail screen as
  they already are today.
- Optional (implementer's discretion, but if shown, it must follow this rule): a combined
  "إجمالي النقد الخارج = مصروفات + مدفوعات الموردين" figure, styled and labeled distinctly from
  any "صافي الربح"/"net profit" figure on the same screen — e.g. a separate card with a caption
  identifying it as a cash-flow total, never placed where it could be read as a profit number.

## Localization
New labels: مدفوعات الموردين, إجمالي النقد الخارج (if shown), a short caption clarifying the
cash-flow figure is not net profit (e.g. "تدفق نقدي، ليس صافي الربح").

## Acceptance criteria
- [ ] Supplier payments for the selected range list in the Expenses tab's "مدفوعات الموردين"
      section, correctly attributed to supplier and deal.
- [ ] Net profit, wherever shown (dashboard, deal detail, any report), is numerically
      **unchanged** by the presence of this new section — verified by comparing net profit
      before and after this phase ships on the same data.
- [ ] Supplier payments never appear as rows in the expenses list itself, and are never summed
      into the expenses total that feeds net profit.
- [ ] If the combined cash-out figure is implemented, it is visually and textually labeled as a
      cash-flow total, never as profit, and its value equals `expensesTotal + supplierPaymentsTotal`
      for the same range exactly.

## Out of scope
- Cash-basis net profit as an alternative reporting mode — net profit stays COGS-based
  everywhere in this app; this phase only adds a visibility feature, not an accounting-model
  change.
- Editing or deleting a supplier payment from this section — that capability, if needed, stays
  on the deal detail screen where supplier payments are already recorded and managed.
