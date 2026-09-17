import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../model/payment_model.dart';
import '../../../model/refund_model.dart';
import '../../../model/transaction_item_model.dart';
import '../../../model/transaction_with_items_model.dart';
import '../../../view_model/cubit/dashboard/dashboard_cubit.dart';
import '../../../view_model/cubit/deals/deals_cubit.dart';
import '../../../view_model/cubit/deals/deals_state.dart';
import '../../../view_model/cubit/expenses/expenses_cubit.dart';
import '../../../view_model/cubit/payments/payments_cubit.dart';
import '../../../view_model/provider/items_cache_provider.dart';
import '../../../view_model/provider/suppliers_cache_provider.dart';
import '../../../view_model/utils/currency_formatter.dart';
import '../../../view_model/utils/date_utils.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_text_styles.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/error_state_widget.dart';
import '../../core/widgets/kpi_card.dart';
import '../../core/widgets/loading_widget.dart';
import '../../core/widgets/payment_status_chip.dart';
import '../../core/widgets/primary_button.dart';
import 'widgets/add_payment_dialog.dart';
import 'widgets/line_item_tile.dart';
import 'widgets/per_day_rental_grid.dart';
import 'widgets/return_settlement_dialog.dart';

/// One deal in full: lines, both payment sides (with per-supplier payables),
/// refunds, and the admin edit / delete actions.
class DealDetailScreen extends StatefulWidget {
  const DealDetailScreen({super.key, required this.dealId});

  final int dealId;

  @override
  State<DealDetailScreen> createState() => _DealDetailScreenState();
}

class _DealDetailScreenState extends State<DealDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await context.read<DealsCubit>().loadDeal(widget.dealId);
    if (mounted) await context.read<PaymentsCubit>().load(widget.dealId);
  }

  /// Every action below mutates deals/payments/refunds — the dashboard's
  /// underlying tables — so it must stay live without the admin navigating
  /// away and back. A commission edit also mirrors into an expense row, so
  /// the Expenses tab must refresh too.
  Future<void> _refreshDashboard() async {
    if (mounted) await context.read<DashboardCubit>().refresh();
    if (mounted) await context.read<ExpensesCubit>().load();
  }

  /// Passed to [PerDayRentalGrid], whose own payment mark/unmark actions
  /// mutate the deal's payments directly.
  Future<void> _onLineMutated() async {
    await _load();
    await _refreshDashboard();
  }

  Future<void> _addPayment(
    TransactionWithItemsModel deal,
    PaymentParty party, {
    int? supplierId,
  }) async {
    final bool saved = await AddPaymentDialog.show(
      context,
      deal: deal,
      party: party,
      supplierId: supplierId,
    );
    if (saved && mounted) {
      await _load();
      await _refreshDashboard();
    }
  }

  /// Undo/refund one payment. The row is never deleted — it stays visible in
  /// the history with a "ملغاة" mark — it just stops counting toward the
  /// balance.
  Future<void> _voidPayment(PaymentModel payment) async {
    final bool ok = await ConfirmDialog.show(
      context,
      title: 'إلغاء هذه الدفعة؟',
      message: 'سيتم اعتبار هذه الدفعة كأنها لم تُدفع في حساب الرصيد، لكنها '
          'تبقى ظاهرة في السجل بعلامة "ملغاة". لا يمكن التراجع عن هذا '
          'الإجراء.',
      confirmLabel: 'إلغاء الدفعة',
      isDestructive: true,
    );
    if (!ok || !mounted) return;

    final PaymentsCubit cubit = context.read<PaymentsCubit>();
    final bool done = await cubit.voidPayment(payment.id, widget.dealId);
    if (!mounted) return;
    if (done) {
      await _load();
      await _refreshDashboard();
    } else {
      final String? message = cubit.state.errorMessage;
      if (message != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
        cubit.clearError();
      }
    }
  }

  Future<void> _edit() async {
    final Object? saved = await Navigator.of(context)
        .pushNamed(AppRoutes.addEditDeal, arguments: widget.dealId);
    if (saved == true && mounted) {
      await _load();
      await _refreshDashboard();
    }
  }

  Future<void> _closeCarLine(
    TransactionWithItemsModel deal,
    TransactionItemModel line,
  ) async {
    final bool done = await ReturnSettlementDialog.show(
      context,
      transactionId: deal.id,
      line: line,
      alreadyPaid: deal.payments
          .where((PaymentModel p) => p.transactionItemId == line.id)
          .fold<double>(0, (double sum, PaymentModel p) => sum + p.amount),
    );
    if (done && mounted) {
      await _load();
      await _refreshDashboard();
    }
  }

  Future<void> _reopenCarLine(
    TransactionWithItemsModel deal,
    TransactionItemModel line,
  ) async {
    final bool ok = await ConfirmDialog.show(
      context,
      title: 'تأكيد إعادة الفتح',
      message: 'سيتم مسح تسوية هذا السطر (الكيلومتر المستلم وسعر ورسوم '
          'الكيلومتر الإضافي) ويجب إعادة إدخالها عند الإغلاق التالي.',
      confirmLabel: 'إعادة فتح',
    );
    if (!ok || !mounted) return;

    final bool done = await context.read<DealsCubit>().reopenCarLine(
          transactionId: deal.id,
          transactionItemId: line.id,
        );
    if (done && mounted) {
      await _load();
      await _refreshDashboard();
    }
  }

  Future<void> _openRefund() async {
    final Object? done = await Navigator.of(context)
        .pushNamed(AppRoutes.refund, arguments: widget.dealId);
    if (done == true && mounted) {
      await _load();
      await _refreshDashboard();
    }
  }

  Future<void> _delete() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool ok = await ConfirmDialog.show(
      context,
      title: l10n.deleteDealTitle,
      message: l10n.deleteDealMessage,
      confirmLabel: l10n.delete,
      isDestructive: true,
      warning: l10n.deleteDealWarning,
    );
    if (!ok || !mounted) return;

    final DealsCubit cubit = context.read<DealsCubit>();
    final bool deleted = await cubit.deleteDeal(
      widget.dealId,
      itemsCache: context.read<ItemsCacheProvider>(),
    );

    if (!mounted) return;
    if (deleted) {
      await _refreshDashboard();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } else {
      final String? message = cubit.state.errorMessage;
      if (message != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
        cubit.clearError();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return BlocBuilder<DealsCubit, DealsState>(
      builder: (BuildContext context, DealsState state) {
        final TransactionWithItemsModel? deal = state.selectedDeal;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              deal == null ? l10n.dealDetail : 'Deal #${deal.id}',
            ),
            actions: <Widget>[
              if (deal != null) ...<Widget>[
                TextButton.icon(
                  onPressed: _openRefund,
                  icon: const Icon(Icons.undo, color: AppColors.white, size: 18),
                  label: Text(l10n.refund,
                      style: const TextStyle(color: AppColors.white)),
                ),
                IconButton(
                  tooltip: l10n.edit,
                  onPressed: _edit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: l10n.delete,
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
              const SizedBox(width: 8),
            ],
          ),
          body: _body(context, state, l10n),
        );
      },
    );
  }

  Widget _body(BuildContext context, DealsState state, AppLocalizations l10n) {
    if (state.isLoading && state.selectedDeal == null) {
      return LoadingWidget(message: l10n.loading);
    }

    if (state.isFailure) {
      return ErrorStateWidget(
        message: state.errorMessage ?? l10n.errorGeneric,
        onRetry: _load,
      );
    }

    final TransactionWithItemsModel? deal = state.selectedDeal;
    if (deal == null) return LoadingWidget(message: l10n.loading);

    final SuppliersCacheProvider suppliers =
        context.watch<SuppliersCacheProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.contentPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _summary(deal, l10n),
          const SizedBox(height: 24),
          Text(l10n.lineItems, style: AppTextStyles.title),
          const SizedBox(height: 12),
          for (final TransactionItemModel line in deal.items) ...<Widget>[
            LineItemTile(line: line),
            if (line.isPerDay) ...<Widget>[
              const SizedBox(height: 8),
              PerDayRentalGrid(deal: deal, line: line, onChanged: _onLineMutated),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: line.isReturned
                    ? OutlinedButton.icon(
                        onPressed: () => _reopenCarLine(deal, line),
                        icon: const Icon(Icons.replay, size: 16),
                        label: const Text('إعادة فتح'),
                      )
                    : OutlinedButton.icon(
                        onPressed: () => _closeCarLine(deal, line),
                        icon: const Icon(Icons.assignment_return_outlined,
                            size: 16),
                        label: const Text('إغلاق'),
                      ),
              ),
              const SizedBox(height: 16),
            ],
          ],
          const SizedBox(height: 24),
          _clientSection(deal, l10n),
          const SizedBox(height: 24),
          _supplierSection(deal, suppliers, l10n),
          if (deal.refunds.isNotEmpty) ...<Widget>[
            const SizedBox(height: 24),
            _refundSection(deal, l10n),
          ],
        ],
      ),
    );
  }

  Widget _summary(TransactionWithItemsModel deal, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              deal.transaction.clientName ?? '—',
              style: AppTextStyles.headline,
            ),
            const SizedBox(width: 14),
            DealStatusChip(status: deal.transaction.status),
            const SizedBox(width: 14),
            Text(
              AppDateUtils.formatDateTime(deal.transaction.dateTime),
              style: AppTextStyles.caption,
              textDirection: TextDirection.ltr,
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double width =
                (constraints.maxWidth - 3 * 16) / 4;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: <Widget>[
                SizedBox(
                  width: width,
                  child: KpiCard(
                    label: l10n.total,
                    value: CurrencyFormatter.format(deal.netRevenue),
                    icon: Icons.receipt_outlined,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: KpiCard(
                    label: l10n.cost,
                    value: CurrencyFormatter.format(deal.netCost),
                    icon: Icons.payments_outlined,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: KpiCard(
                    label: l10n.profit,
                    value: CurrencyFormatter.signed(deal.netProfit),
                    icon: Icons.trending_up,
                    valueColor: deal.netProfit >= 0
                        ? AppColors.success
                        : AppColors.danger,
                    accent: deal.netProfit >= 0
                        ? AppColors.success
                        : AppColors.danger,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: KpiCard(
                    label: l10n.discount,
                    value:
                        CurrencyFormatter.format(deal.transaction.discount),
                    icon: Icons.percent,
                  ),
                ),
              ],
            );
          },
        ),
        if ((deal.transaction.commissionAmount ?? 0) > 0) ...<Widget>[
          const SizedBox(height: 14),
          Text(
            'العمولة'
            '${deal.transaction.commissionName?.isNotEmpty == true ? ' (${deal.transaction.commissionName})' : ''}'
            ': ${CurrencyFormatter.format(deal.transaction.commissionAmount!)}',
            style: AppTextStyles.bodyMuted,
          ),
        ],
        if (deal.transaction.notes?.isNotEmpty == true) ...<Widget>[
          const SizedBox(height: 14),
          Text(deal.transaction.notes!, style: AppTextStyles.bodyMuted),
        ],
      ],
    );
  }

  Widget _clientSection(
      TransactionWithItemsModel deal, AppLocalizations l10n) {
    final List<PaymentModel> payments = deal.payments
        .where((PaymentModel p) => p.party == PaymentParty.client)
        .toList();

    return _Section(
      title: l10n.clientPayment,
      trailing: Row(
        children: <Widget>[
          PaymentStatusChip(status: deal.displayedClientStatus),
          if (deal.hasClientStatusOverride) ...<Widget>[
            const SizedBox(width: 6),
            Text(
              '(يدوي)',
              style: AppTextStyles.caption.copyWith(color: AppColors.warning),
            ),
          ],
          const SizedBox(width: 12),
          PrimaryButton(
            label: l10n.addPayment,
            icon: Icons.add,
            onPressed: () => _addPayment(deal, PaymentParty.client),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _BalanceRow(
            owed: deal.netClientOwed,
            settled: deal.clientPaid,
            outstanding: deal.clientOutstanding,
            owedLabel: l10n.owed,
            settledLabel: l10n.collected,
          ),
          const SizedBox(height: 12),
          if (payments.isEmpty)
            Text(l10n.paymentsEmpty, style: AppTextStyles.bodyMuted)
          else
            for (final PaymentModel p in payments)
              _PaymentTile(payment: p, onVoid: _voidPayment),
        ],
      ),
    );
  }

  Widget _supplierSection(
    TransactionWithItemsModel deal,
    SuppliersCacheProvider suppliers,
    AppLocalizations l10n,
  ) {
    return _Section(
      title: l10n.supplierPayment,
      trailing: PaymentStatusChip(status: deal.supplierStatus),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // A payable is per supplier per transaction, never the whole
          // totalCost, so each supplier gets its own block.
          for (final int supplierId in deal.supplierIds) ...<Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: <Widget>[
                  Text(
                    suppliers.nameOf(supplierId),
                    style: AppTextStyles.subtitle,
                  ),
                  const SizedBox(width: 12),
                  PaymentStatusChip(
                    status: deal.supplierStatusFor(supplierId),
                    compact: true,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _addPayment(
                      deal,
                      PaymentParty.supplier,
                      supplierId: supplierId,
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(l10n.addPayment),
                  ),
                ],
              ),
            ),
            _BalanceRow(
              owed: deal.supplierOwed(supplierId),
              settled: deal.supplierPaidTo(supplierId),
              outstanding: deal.supplierOutstandingFor(supplierId),
              owedLabel: l10n.payable,
              settledLabel: l10n.paid,
            ),
            const SizedBox(height: 8),
            for (final PaymentModel p in deal.payments.where(
              (PaymentModel p) =>
                  p.party == PaymentParty.supplier &&
                  p.supplierId == supplierId,
            ))
              _PaymentTile(payment: p, onVoid: _voidPayment),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _refundSection(
      TransactionWithItemsModel deal, AppLocalizations l10n) {
    return _Section(
      title: l10n.refunds,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final RefundModel r in deal.refunds)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: <Widget>[
                  Text(
                    AppDateUtils.formatDate(r.dateTime),
                    style: AppTextStyles.caption,
                    textDirection: TextDirection.ltr,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      r.reason?.isNotEmpty == true ? r.reason! : '—',
                      style: AppTextStyles.body,
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(r.totalRefunded),
                    style: AppTextStyles.money
                        .copyWith(color: AppColors.warning),
                    textDirection: TextDirection.ltr,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(title, style: AppTextStyles.title),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({
    required this.owed,
    required this.settled,
    required this.outstanding,
    required this.owedLabel,
    required this.settledLabel,
  });

  final double owed;
  final double settled;
  final double outstanding;
  final String owedLabel;
  final String settledLabel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 32,
      runSpacing: 10,
      children: <Widget>[
        _cell(owedLabel, owed, null),
        _cell(settledLabel, settled, AppColors.success),
        _cell(
          'Outstanding',
          outstanding,
          outstanding > 0.005 ? AppColors.danger : AppColors.success,
        ),
      ],
    );
  }

  Widget _cell(String label, double value, Color? color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 2),
        Text(
          CurrencyFormatter.format(value),
          style: AppTextStyles.money.copyWith(color: color),
          textDirection: TextDirection.ltr,
        ),
      ],
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment, required this.onVoid});

  final PaymentModel payment;

  /// Undo/refund this payment. The tile still renders (with a "ملغاة" mark)
  /// after it's voided — it just stops showing the action button.
  final ValueChanged<PaymentModel> onVoid;

  @override
  Widget build(BuildContext context) {
    final bool voided = payment.voided;
    final TextStyle captionStyle = voided
        ? AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            decoration: TextDecoration.lineThrough,
          )
        : AppTextStyles.caption;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: <Widget>[
          Icon(
            voided ? Icons.cancel_outlined : Icons.check_circle_outline,
            size: 15,
            color: voided ? AppColors.textSecondary : AppColors.success,
          ),
          const SizedBox(width: 10),
          Text(
            AppDateUtils.formatDate(payment.dateTime),
            style: captionStyle,
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(width: 14),
          Text(
            AddPaymentDialog.methodLabel(payment.method),
            style: captionStyle,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              payment.notes ?? '',
              style: captionStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (voided) ...<Widget>[
            Text(
              'ملغاة',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Text(
            CurrencyFormatter.format(payment.amount),
            style: AppTextStyles.money.copyWith(
              color: voided ? AppColors.textSecondary : null,
              decoration: voided ? TextDecoration.lineThrough : null,
            ),
            textDirection: TextDirection.ltr,
          ),
          if (!voided) ...<Widget>[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'إلغاء / استرجاع الدفعة',
              icon: const Icon(Icons.undo, size: 16),
              color: AppColors.danger,
              visualDensity: VisualDensity.compact,
              onPressed: () => onVoid(payment),
            ),
          ],
        ],
      ),
    );
  }
}
