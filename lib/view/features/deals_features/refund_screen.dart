import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../model/transaction_item_model.dart';
import '../../../model/transaction_with_items_model.dart';
import '../../../view_model/cubit/refund/refund_cubit.dart';
import '../../../view_model/cubit/refund/refund_state.dart';
import '../../../view_model/provider/items_cache_provider.dart';
import '../../../view_model/utils/currency_formatter.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_text_styles.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/widgets/error_state_widget.dart';
import '../../core/widgets/loading_widget.dart';
import '../../core/widgets/primary_button.dart';
import 'widgets/refund_line_tile.dart';

/// Partial or full refund of a deal. The whole write — refund rows, snapshot
/// copies, status update and single-use release — is one Drift transaction.
class RefundScreen extends StatefulWidget {
  const RefundScreen({super.key, required this.dealId});

  final int dealId;

  @override
  State<RefundScreen> createState() => _RefundScreenState();
}

class _RefundScreenState extends State<RefundScreen> {
  final TextEditingController _reason = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => context.read<RefundCubit>().load(widget.dealId));
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final RefundCubit cubit = context.read<RefundCubit>();

    final bool ok = await ConfirmDialog.show(
      context,
      title: 'تأكيد هذا المرتجع؟',
      message: 'سيتم تسجيل السطور المرتجعة بنفس قيم التكلفة والسعر الأصلية.',
      confirmLabel: 'تأكيد المرتجع',
      warning: 'سيتم إعادة حساب أرصدة العميل والمورد، وأي عنصر أحادي '
          'الاستخدام تم إرجاعه بالكامل سيعود متاحاً مرة أخرى.',
    );
    if (!ok || !mounted) return;

    final bool done = await cubit.submit(
      itemsCache: context.read<ItemsCacheProvider>(),
    );

    if (!mounted) return;
    if (done) {
      Navigator.of(context).pop(true);
    } else {
      final String? message = cubit.state.errorMessage;
      if (message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppColors.danger),
        );
        cubit.clearError();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return BlocBuilder<RefundCubit, RefundState>(
      builder: (BuildContext context, RefundState state) {
        return Scaffold(
          appBar: AppBar(
            title: Text('${l10n.refundDeal} #${widget.dealId}'),
            actions: <Widget>[
              TextButton(
                onPressed:
                    state.deal == null ? null : context.read<RefundCubit>().selectFull,
                child: Text(
                  l10n.refundFull,
                  style: const TextStyle(color: AppColors.white),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: _body(context, state, l10n),
          bottomNavigationBar:
              state.deal == null ? null : _footer(context, state, l10n),
        );
      },
    );
  }

  Widget _body(BuildContext context, RefundState state, AppLocalizations l10n) {
    if (state.isLoading) return LoadingWidget(message: l10n.loading);

    if (state.isFailure && state.deal == null) {
      return ErrorStateWidget(
        message: state.errorMessage ?? l10n.errorGeneric,
        onRetry: () => context.read<RefundCubit>().load(widget.dealId),
      );
    }

    final TransactionWithItemsModel? deal = state.deal;
    if (deal == null) return LoadingWidget(message: l10n.loading);

    final bool anythingRefundable = deal.items.any(
      (TransactionItemModel l) => l.qty - (state.refundedQty[l.id] ?? 0) > 0,
    );

    if (!anythingRefundable) {
      return EmptyStateWidget(
        title: 'لا يوجد شيء متبقٍ لإرجاعه',
        message: 'Every line on this deal has already been fully refunded.',
        icon: Icons.undo,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.contentPadding),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                deal.transaction.clientName ?? '—',
                style: AppTextStyles.headline,
              ),
              const SizedBox(height: 18),
              for (final TransactionItemModel line in deal.items)
                RefundLineTile(
                  line: line,
                  alreadyRefunded: state.refundedQty[line.id] ?? 0,
                  selectedQty: state.selectedQty[line.id] ?? 0,
                  onQtyChanged: (int qty) =>
                      context.read<RefundCubit>().setLineQty(line.id, qty),
                ),
              const SizedBox(height: 12),
              AppTextField(
                label: l10n.refundReason,
                controller: _reason,
                maxLines: 2,
                onChanged: context.read<RefundCubit>().setReason,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footer(
      BuildContext context, RefundState state, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(l10n.refundTotal, style: AppTextStyles.caption),
              Text(
                CurrencyFormatter.format(state.refundTotal),
                style: AppTextStyles.moneyLarge
                    .copyWith(color: AppColors.warning),
                textDirection: TextDirection.ltr,
              ),
            ],
          ),
          const SizedBox(width: 28),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('Cost refunded', style: AppTextStyles.caption),
              Text(
                CurrencyFormatter.format(state.refundCostTotal),
                style: AppTextStyles.money,
                textDirection: TextDirection.ltr,
              ),
            ],
          ),
          const Spacer(),
          TextButton(
            onPressed: context.read<RefundCubit>().clearSelection,
            child: const Text('مسح'),
          ),
          const SizedBox(width: 12),
          PrimaryButton(
            label: l10n.submitRefund,
            icon: Icons.undo,
            isLoading: state.isSubmitting,
            onPressed: state.hasSelection ? _submit : null,
          ),
        ],
      ),
    );
  }
}
