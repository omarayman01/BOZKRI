import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../model/supplier_model.dart';
import '../../../view_model/cubit/suppliers/suppliers_cubit.dart';
import '../../../view_model/cubit/suppliers/suppliers_state.dart';
import '../../../view_model/provider/suppliers_cache_provider.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_text_styles.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/widgets/app_data_table.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/error_state_widget.dart';
import '../../core/widgets/loading_widget.dart';
import '../../core/widgets/primary_button.dart';
import 'widgets/supplier_row.dart';

/// Supplier list. Item management deliberately lives inside the supplier
/// detail screen, not as a top-level destination.
class SuppliersScreen extends StatelessWidget {
  const SuppliersScreen({super.key});

  Future<void> _reload(BuildContext context) => context
      .read<SuppliersCubit>()
      .load(context.read<SuppliersCacheProvider>());

  Future<void> _openForm(BuildContext context, [SupplierModel? supplier]) async {
    final Object? saved = await Navigator.of(context)
        .pushNamed(AppRoutes.addEditSupplier, arguments: supplier);
    if (saved == true && context.mounted) await _reload(context);
  }

  Future<void> _confirmDelete(
      BuildContext context, SupplierModel supplier) async {
    final bool ok = await ConfirmDialog.show(
      context,
      title: 'حذف ${supplier.name}؟',
      message: 'سيتم حذف هذا المورد نهائياً.',
      confirmLabel: 'حذف',
      isDestructive: true,
    );
    if (!ok || !context.mounted) return;

    final SuppliersCubit cubit = context.read<SuppliersCubit>();
    final bool deleted = await cubit.deleteSupplier(
        context.read<SuppliersCacheProvider>(), supplier.id);
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

    return BlocBuilder<SuppliersCubit, SuppliersState>(
      builder: (BuildContext context, SuppliersState state) {
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
                      prefixIcon: Icons.search,
                      onChanged: context.read<SuppliersCubit>().search,
                    ),
                  ),
                  const SizedBox(width: 16),
                  PrimaryButton(
                    label: l10n.newSupplier,
                    icon: Icons.add_business_outlined,
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
      BuildContext context, SuppliersState state, AppLocalizations l10n) {
    if (state.isLoading) return LoadingWidget(message: l10n.loading);

    if (state.isFailure) {
      return ErrorStateWidget(
        message: state.errorMessage ?? l10n.errorGeneric,
        onRetry: () => _reload(context),
      );
    }

    final List<SupplierModel> suppliers = state.visibleSuppliers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('${suppliers.length} ${l10n.suppliersTitle}',
            style: AppTextStyles.label),
        const SizedBox(height: 10),
        Expanded(
          child: AppDataTable(
            columns: SupplierRow.columns(),
            emptyTitle: l10n.suppliersEmptyTitle,
            emptyMessage: l10n.suppliersEmptyMessage,
            emptyIcon: Icons.store_outlined,
            emptyActionLabel: l10n.newSupplier,
            onEmptyAction: () => _openForm(context),
            rows: suppliers
                .map((SupplierModel s) => SupplierRow.build(
                      s,
                      onOpen: () => Navigator.of(context).pushNamed(
                        AppRoutes.supplierDetail,
                        arguments: s.id,
                      ),
                      onEdit: () => _openForm(context, s),
                      onDelete: () => _confirmDelete(context, s),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}
