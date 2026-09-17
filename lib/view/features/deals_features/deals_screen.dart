import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../model/transaction_with_items_model.dart';
import '../../../view_model/cubit/dashboard/dashboard_cubit.dart';
import '../../../view_model/cubit/deals/deals_cubit.dart';
import '../../../view_model/cubit/deals/deals_state.dart';
import '../../../view_model/cubit/expenses/expenses_cubit.dart';
import '../../../view_model/provider/items_cache_provider.dart';
import '../../../view_model/utils/currency_formatter.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_text_styles.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/widgets/app_data_table.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/error_state_widget.dart';
import '../../core/widgets/loading_widget.dart';
import '../../core/widgets/primary_button.dart';
import 'widgets/deal_row.dart';

/// Dense list of every deal, with full admin create / edit / delete.
class DealsScreen extends StatelessWidget {
  const DealsScreen({super.key});

  /// A deal save/delete can create, update, or clear its mirrored commission
  /// expense, so the Expenses tab must refresh alongside the dashboard.
  Future<void> _reload(BuildContext context) async {
    await context.read<DealsCubit>().loadDeals();
    if (context.mounted) await context.read<DashboardCubit>().refresh();
    if (context.mounted) await context.read<ExpensesCubit>().load();
  }

  Future<void> _openBuilder(BuildContext context, [int? dealId]) async {
    final Object? saved = await Navigator.of(context)
        .pushNamed(AppRoutes.addEditDeal, arguments: dealId);
    if (saved == true && context.mounted) await _reload(context);
  }

  /// Deletion is allowed at any time — there is no lock. The cascade and the
  /// single-use release both happen inside one Drift transaction.
  Future<void> _confirmDelete(
      BuildContext context, TransactionWithItemsModel deal) async {
    final AppLocalizations l10n = AppLocalizations.of(context);

    final bool ok = await ConfirmDialog.show(
      context,
      title: l10n.deleteDealTitle,
      message: l10n.deleteDealMessage,
      confirmLabel: l10n.delete,
      isDestructive: true,
      warning: l10n.deleteDealWarning,
    );
    if (!ok || !context.mounted) return;

    final DealsCubit cubit = context.read<DealsCubit>();
    final bool deleted = await cubit.deleteDeal(
      deal.id,
      itemsCache: context.read<ItemsCacheProvider>(),
    );

    if (!context.mounted) return;
    if (deleted) {
      await _reload(context);
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
        return Padding(
          padding: const EdgeInsets.all(AppConstants.contentPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: AppTextField(
                      label: l10n.search,
                      hint: 'Client, supplier or deal number',
                      prefixIcon: Icons.search,
                      onChanged: context.read<DealsCubit>().search,
                    ),
                  ),
                  const SizedBox(width: 16),
                  PrimaryButton(
                    label: l10n.newDeal,
                    icon: Icons.add,
                    onPressed: () => _openBuilder(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(child: _body(context, state, l10n)),
            ],
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, DealsState state, AppLocalizations l10n) {
    final ItemsCacheProvider itemsCache = context.watch<ItemsCacheProvider>();
    if (state.isLoading) return LoadingWidget(message: l10n.loading);

    if (state.isFailure) {
      return ErrorStateWidget(
        message: state.errorMessage ?? l10n.errorGeneric,
        onRetry: () => _reload(context),
      );
    }

    final List<TransactionWithItemsModel> deals = state.visibleDeals;

    final double revenue = deals.fold<double>(
        0, (double sum, TransactionWithItemsModel d) => sum + d.netRevenue);
    final double profit = deals.fold<double>(
        0, (double sum, TransactionWithItemsModel d) => sum + d.netProfit);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text('${deals.length} ${l10n.dealsTitle}',
                style: AppTextStyles.label),
            const SizedBox(width: 20),
            Text(
              '${l10n.total}: ${CurrencyFormatter.format(revenue)}',
              style: AppTextStyles.caption,
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(width: 16),
            Text(
              '${l10n.profit}: ${CurrencyFormatter.signed(profit)}',
              style: AppTextStyles.caption,
              textDirection: TextDirection.ltr,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: AppDataTable(
            columns: DealRow.columns(),
            minWidth: 1180,
            emptyTitle: l10n.dealsEmptyTitle,
            emptyMessage: l10n.dealsEmptyMessage,
            emptyIcon: Icons.receipt_long_outlined,
            emptyActionLabel: l10n.newDeal,
            onEmptyAction: () => _openBuilder(context),
            rows: deals
                .map((TransactionWithItemsModel d) => DealRow.build(
                      d,
                      itemsCache: itemsCache,
                      onOpen: () => Navigator.of(context)
                          .pushNamed(AppRoutes.dealDetail, arguments: d.id)
                          .then((Object? _) {
                        if (context.mounted) _reload(context);
                      }),
                      onEdit: () => _openBuilder(context, d.id),
                      onDelete: () => _confirmDelete(context, d),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}
