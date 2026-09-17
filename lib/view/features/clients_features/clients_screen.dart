import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../model/client_model.dart';
import '../../../view_model/cubit/clients/clients_cubit.dart';
import '../../../view_model/cubit/clients/clients_state.dart';
import '../../../view_model/provider/clients_cache_provider.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_text_styles.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/widgets/app_data_table.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/error_state_widget.dart';
import '../../core/widgets/loading_widget.dart';
import '../../core/widgets/primary_button.dart';
import 'widgets/client_row.dart';

/// Dense client list with search, add / edit / delete and a tap-through to the
/// client detail drill-down.
class ClientsScreen extends StatelessWidget {
  const ClientsScreen({super.key});

  Future<void> _reload(BuildContext context) =>
      context.read<ClientsCubit>().load(context.read<ClientsCacheProvider>());

  Future<void> _openForm(BuildContext context, [ClientModel? client]) async {
    final Object? saved = await Navigator.of(context)
        .pushNamed(AppRoutes.addEditClient, arguments: client);
    if (saved == true && context.mounted) await _reload(context);
  }

  Future<void> _confirmDelete(BuildContext context, ClientModel client) async {
    final bool ok = await ConfirmDialog.show(
      context,
      title: 'حذف ${client.name}؟',
      message: 'سيتم حذف هذا العميل نهائياً.',
      confirmLabel: 'حذف',
      isDestructive: true,
    );
    if (!ok || !context.mounted) return;

    final ClientsCubit cubit = context.read<ClientsCubit>();
    final bool deleted =
        await cubit.deleteClient(context.read<ClientsCacheProvider>(), client.id);
    if (!deleted && context.mounted) {
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

    return BlocBuilder<ClientsCubit, ClientsState>(
      builder: (BuildContext context, ClientsState state) {
        return Padding(
          padding: const EdgeInsets.all(AppConstants.contentPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: SizedBox(
                      width: 340,
                      child: AppTextField(
                        label: l10n.search,
                        prefixIcon: Icons.search,
                        onChanged: context.read<ClientsCubit>().search,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  PrimaryButton(
                    label: l10n.newClient,
                    icon: Icons.person_add_alt,
                    onPressed: () => _openForm(context),
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

  Widget _body(
      BuildContext context, ClientsState state, AppLocalizations l10n) {
    if (state.isLoading) return LoadingWidget(message: l10n.loading);

    if (state.isFailure) {
      return ErrorStateWidget(
        message: state.errorMessage ?? l10n.errorGeneric,
        onRetry: () => _reload(context),
      );
    }

    final List<ClientModel> clients = state.visibleClients;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('${clients.length} ${l10n.clientsTitle}',
            style: AppTextStyles.label),
        const SizedBox(height: 10),
        Expanded(
          child: AppDataTable(
            columns: ClientRow.columns(),
            emptyTitle: l10n.clientsEmptyTitle,
            emptyMessage: l10n.clientsEmptyMessage,
            emptyIcon: Icons.people_outline,
            emptyActionLabel: l10n.newClient,
            onEmptyAction: () => _openForm(context),
            rows: clients
                .map((ClientModel c) => ClientRow.build(
                      c,
                      onOpen: () => Navigator.of(context).pushNamed(
                        AppRoutes.clientDetail,
                        arguments: c.id,
                      ),
                      onEdit: () => _openForm(context, c),
                      onDelete: () => _confirmDelete(context, c),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}
