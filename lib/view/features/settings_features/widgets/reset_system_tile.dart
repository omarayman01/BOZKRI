import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../../../view_model/cubit/clients/clients_cubit.dart';
import '../../../../view_model/cubit/dashboard/dashboard_cubit.dart';
import '../../../../view_model/cubit/deals/deals_cubit.dart';
import '../../../../view_model/cubit/expenses/expenses_cubit.dart';
import '../../../../view_model/cubit/item_types/item_types_cubit.dart';
import '../../../../view_model/cubit/items/items_cubit.dart';
import '../../../../view_model/cubit/settings/settings_cubit.dart';
import '../../../../view_model/cubit/settings/settings_state.dart';
import '../../../../view_model/cubit/suppliers/suppliers_cubit.dart';
import '../../../../view_model/provider/clients_cache_provider.dart';
import '../../../../view_model/provider/expiry_provider.dart';
import '../../../../view_model/provider/items_cache_provider.dart';
import '../../../../view_model/provider/suppliers_cache_provider.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_text_styles.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/primary_button.dart';

/// "إعادة تعيين النظام" — a destructive, all-or-nothing wipe of every
/// client, supplier, item, deal, payment, refund, and expense. Item types/
/// fields and expense categories are kept, so the app isn't left completely
/// unconfigured. Unlike Backup/Restore, this never closes the database
/// connection, so no app restart is needed — every cache/cubit is reloaded
/// in place right after, the same sequence `MainShell` runs at startup.
class ResetSystemTile extends StatelessWidget {
  const ResetSystemTile({super.key});

  Future<void> _reloadEverything(BuildContext context) async {
    final ClientsCacheProvider clients = context.read<ClientsCacheProvider>();
    final SuppliersCacheProvider suppliers =
        context.read<SuppliersCacheProvider>();
    final ItemsCacheProvider items = context.read<ItemsCacheProvider>();
    final ExpiryProvider expiry = context.read<ExpiryProvider>();

    await context.read<ClientsCubit>().load(clients);
    if (!context.mounted) return;
    await context.read<SuppliersCubit>().load(suppliers);
    if (!context.mounted) return;
    await context.read<ItemTypesCubit>().load(items);
    if (!context.mounted) return;
    await context.read<ItemsCubit>().loadAll(items, expiry);
    if (!context.mounted) return;
    await context.read<DealsCubit>().loadDeals();
    if (!context.mounted) return;
    await context.read<ExpensesCubit>().load();
    if (!context.mounted) return;
    await context.read<DashboardCubit>().refresh();
  }

  Future<void> _reset(BuildContext context) async {
    final bool ok = await ConfirmDialog.show(
      context,
      title: 'إعادة تعيين النظام؟',
      message: 'سيتم حذف جميع العملاء والموردين والأصناف والصفقات والدفعات '
          'والمرتجعات والمصروفات نهائياً. أنواع الأصناف وفئات المصروفات '
          'ستبقى كما هي. يمكنك عمل نسخة احتياطية أولاً من الأعلى إذا أردت '
          'الاحتفاظ بالبيانات الحالية.',
      confirmLabel: 'إعادة التعيين',
      isDestructive: true,
      warning: 'هذا الإجراء لا يمكن التراجع عنه.',
    );
    if (!ok || !context.mounted) return;

    final bool success = await context.read<SettingsCubit>().resetSystem();
    if (!context.mounted || !success) return;
    await _reloadEverything(context);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SettingsCubit, SettingsState>(
      listener: (BuildContext context, SettingsState state) {
        if (state.errorMessage != null && state.action == SettingsAction.reset) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppColors.danger,
            ),
          );
          context.read<SettingsCubit>().clearError();
        }
      },
      builder: (BuildContext context, SettingsState state) {
        final bool isWorking =
            state.isWorking && state.action == SettingsAction.reset;
        final bool justReset = state.status == SettingsStatus.success &&
            state.action == SettingsAction.reset;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('إعادة تعيين النظام', style: AppTextStyles.label),
            const SizedBox(height: 6),
            const Text(
              'يحذف كل العملاء والموردين والأصناف والصفقات والدفعات '
              'والمرتجعات والمصروفات نهائياً — يحتفظ بأنواع الأصناف وفئات '
              'المصروفات.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'إعادة تعيين النظام',
              icon: Icons.delete_forever_outlined,
              isDestructive: true,
              isLoading: isWorking,
              onPressed: () => _reset(context),
            ),
            if (justReset && state.message != null) ...<Widget>[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.successSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(Icons.check_circle_outline,
                        size: 18, color: AppColors.success),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(state.message!, style: AppTextStyles.caption),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
