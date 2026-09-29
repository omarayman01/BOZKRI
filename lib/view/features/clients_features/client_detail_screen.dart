import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../view_model/cubit/clients/client_detail_cubit.dart';
import '../../../view_model/cubit/clients/client_detail_state.dart';
import '../../../view_model/provider/expiry_provider.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_text_styles.dart';
import '../../core/widgets/error_state_widget.dart';
import '../../core/widgets/loading_widget.dart';
import '../../core/widgets/sync_meta_footer.dart';
import 'widgets/client_balance_card.dart';
import 'widgets/client_items_tab.dart';
import 'widgets/client_payments_tab.dart';
import 'widgets/client_transactions_tab.dart';

/// One client's drill-down: transactions, payments, items taken, balance card.
class ClientDetailScreen extends StatefulWidget {
  const ClientDetailScreen({super.key, required this.clientId});

  final int clientId;

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() => context.read<ClientDetailCubit>().load(
        widget.clientId,
        expiry: context.read<ExpiryProvider>(),
      );

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return BlocBuilder<ClientDetailCubit, ClientDetailState>(
      builder: (BuildContext context, ClientDetailState state) {
        return Scaffold(
          appBar: AppBar(
            title: Text(state.client?.name ?? l10n.clientDetail),
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
      BuildContext context, ClientDetailState state, AppLocalizations l10n) {
    if (state.isLoading) return LoadingWidget(message: l10n.loading);

    if (state.isFailure) {
      return ErrorStateWidget(
        message: state.errorMessage ?? l10n.errorGeneric,
        onRetry: _load,
      );
    }

    if (state.client == null) return LoadingWidget(message: l10n.loading);

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
                if (state.client!.phone?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      state.client!.phone!,
                      style: AppTextStyles.bodyMuted,
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                if (state.client!.passportId?.isNotEmpty == true ||
                    state.client!.nationalId?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 4,
                      children: <Widget>[
                        if (state.client!.passportId?.isNotEmpty == true)
                          Text(
                            '${l10n.passportId}: ${state.client!.passportId}',
                            style: AppTextStyles.bodyMuted,
                            textDirection: TextDirection.ltr,
                          ),
                        if (state.client!.nationalId?.isNotEmpty == true)
                          Text(
                            '${l10n.nationalId}: ${state.client!.nationalId}',
                            style: AppTextStyles.bodyMuted,
                            textDirection: TextDirection.ltr,
                          ),
                      ],
                    ),
                  ),
                if (state.balance != null)
                  ClientBalanceCard(balance: state.balance!),
                SyncMetaFooter(
                  createdAt: state.client!.createdAt,
                  updatedAt: state.client!.updatedAt,
                  updatedBy: state.client!.updatedBy,
                ),
              ],
            ),
          ),
          TabBar(
            tabs: <Widget>[
              Tab(text: '${l10n.transactions} (${state.transactions.length})'),
              Tab(text: '${l10n.payments} (${state.payments.length})'),
              Tab(text: '${l10n.itemsTaken} (${state.items.length})'),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.contentPadding),
              child: TabBarView(
                children: <Widget>[
                  ClientTransactionsTab(transactions: state.transactions),
                  ClientPaymentsTab(payments: state.payments),
                  ClientItemsTab(items: state.items),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
