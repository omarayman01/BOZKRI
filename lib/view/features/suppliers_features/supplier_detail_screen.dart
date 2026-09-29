import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../model/item_model.dart';
import '../../../view_model/cubit/items/items_cubit.dart';
import '../../../view_model/cubit/suppliers/supplier_detail_cubit.dart';
import '../../../view_model/cubit/suppliers/supplier_detail_state.dart';
import '../../../view_model/provider/expiry_provider.dart';
import '../../../view_model/provider/items_cache_provider.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_text_styles.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/error_state_widget.dart';
import '../../core/widgets/loading_widget.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/sync_meta_footer.dart';
import 'add_edit_item_screen.dart';
import 'widgets/supplier_balance_card.dart';
import 'widgets/supplier_items_tab.dart';
import 'widgets/supplier_payments_tab.dart';
import 'widgets/supplier_transactions_tab.dart';

/// One supplier's drill-down: items (with add/edit), deals, payments, payable.
class SupplierDetailScreen extends StatefulWidget {
  const SupplierDetailScreen({super.key, required this.supplierId});

  final int supplierId;

  @override
  State<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() => context.read<SupplierDetailCubit>().load(
        widget.supplierId,
        itemsCache: context.read<ItemsCacheProvider>(),
      );

  Future<void> _openItemForm([ItemModel? item]) async {
    final Object? saved = await Navigator.of(context).pushNamed(
      AppRoutes.addEditItem,
      arguments: AddEditItemArgs(supplierId: widget.supplierId, item: item),
    );
    if (saved != null && mounted) await _load();
  }

  Future<void> _deleteItem(ItemModel item) async {
    final bool ok = await ConfirmDialog.show(
      context,
      title: 'حذف ${item.label}؟',
      message: 'سيتم حذف هذا العنصر وكل قيم حقوله المخصصة.',
      confirmLabel: 'حذف',
      isDestructive: true,
      warning: 'لا يمكن حذف عنصر مستخدم بالفعل في صفقات — قم بتعطيله بدلاً '
          'من ذلك حتى تبقى الأرقام السابقة سليمة.',
    );
    if (!ok || !mounted) return;

    final ItemsCubit cubit = context.read<ItemsCubit>();
    final bool deleted = await cubit.deleteItem(
      context.read<ItemsCacheProvider>(),
      context.read<ExpiryProvider>(),
      item.id,
    );

    if (!mounted) return;
    if (deleted) {
      await _load();
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

    return BlocBuilder<SupplierDetailCubit, SupplierDetailState>(
      builder: (BuildContext context, SupplierDetailState state) {
        return Scaffold(
          appBar: AppBar(
            title: Text(state.supplier?.name ?? l10n.supplierDetail),
            actions: <Widget>[
              IconButton(
                tooltip: l10n.refresh,
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: _body(context, state, l10n),
        );
      },
    );
  }

  Widget _body(
      BuildContext context, SupplierDetailState state, AppLocalizations l10n) {
    if (state.isLoading) return LoadingWidget(message: l10n.loading);

    if (state.isFailure) {
      return ErrorStateWidget(
        message: state.errorMessage ?? l10n.errorGeneric,
        onRetry: _load,
      );
    }

    if (state.supplier == null) return LoadingWidget(message: l10n.loading);

    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(AppConstants.contentPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (state.supplier!.phone?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      state.supplier!.phone!,
                      style: AppTextStyles.bodyMuted,
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                if (state.balance != null)
                  SupplierBalanceCard(balance: state.balance!),
                SyncMetaFooter(
                  createdAt: state.supplier!.createdAt,
                  updatedAt: state.supplier!.updatedAt,
                  updatedBy: state.supplier!.updatedBy,
                ),
              ],
            ),
          ),
          TabBar(
            tabs: <Widget>[
              Tab(text: '${l10n.items} (${state.items.length})'),
              Tab(text: '${l10n.transactions} (${state.transactions.length})'),
              Tab(text: '${l10n.payments} (${state.payments.length})'),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.contentPadding),
              child: TabBarView(
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          PrimaryButton(
                            label: l10n.newItem,
                            icon: Icons.add,
                            onPressed: _openItemForm,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: SupplierItemsTab(
                          items: state.items,
                          onAdd: _openItemForm,
                          onEdit: (ItemModel i) => _openItemForm(i),
                          onDelete: _deleteItem,
                        ),
                      ),
                    ],
                  ),
                  SupplierTransactionsTab(slices: state.transactions),
                  SupplierPaymentsTab(payments: state.payments),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
