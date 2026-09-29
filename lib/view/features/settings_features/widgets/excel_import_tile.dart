import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '../../../../view_model/cubit/clients/clients_cubit.dart';
import '../../../../view_model/cubit/items/items_cubit.dart';
import '../../../../view_model/cubit/settings/settings_cubit.dart';
import '../../../../view_model/cubit/settings/settings_state.dart';
import '../../../../view_model/cubit/suppliers/suppliers_cubit.dart';
import '../../../../view_model/provider/clients_cache_provider.dart';
import '../../../../view_model/provider/expiry_provider.dart';
import '../../../../view_model/provider/items_cache_provider.dart';
import '../../../../view_model/provider/suppliers_cache_provider.dart';
import '../../../../view_model/utils/db_backup_helper.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_text_styles.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/primary_button.dart';

/// "استيراد من إكسل" — a dedicated action for master-data-only import from a
/// `.xlsx` file, separate from the full `.sqlite` restore above so the two
/// very different operations (partial import vs. total replace) are never
/// confused with each other. Imported rows are pushed to Supabase right
/// after (see SettingsCubit._restoreFromXlsx), so this also reaches every
/// other connected device, not just this machine.
class ExcelImportTile extends StatelessWidget {
  const ExcelImportTile({super.key});

  Future<void> _import(BuildContext context) async {
    final String? sourcePath = await DbBackupHelper.pickXlsxSourceFile();
    if (sourcePath == null || !context.mounted) return;

    final bool ok = await ConfirmDialog.show(
      context,
      title: 'استيراد بيانات من إكسل؟',
      message: 'سيتم جلب العملاء والموردين وأنواع الأصناف وحقولها '
          'والأصناف/السيارات من ${p.basename(sourcePath)}، ورفعها إلى '
          'قاعدة البيانات المشتركة (Supabase) مباشرة.',
      confirmLabel: 'استيراد',
      warning: 'لا يجلب هذا الاستيراد الصفقات أو الدفعات أو الأرصدة — '
          'تبقى كما هي دون أي تغيير.',
    );
    if (!ok || !context.mounted) return;

    await context.read<SettingsCubit>().restore(sourcePath: sourcePath);
    if (!context.mounted) return;

    // The import writes straight into the clients/suppliers/items tables
    // with the live connection still open, so every cache-backed list/
    // picker needs reloading here or the admin would only see the new rows
    // after restarting the app.
    await context
        .read<ClientsCubit>()
        .load(context.read<ClientsCacheProvider>());
    if (!context.mounted) return;
    await context
        .read<SuppliersCubit>()
        .load(context.read<SuppliersCacheProvider>());
    if (!context.mounted) return;
    await context.read<ItemsCubit>().loadAll(
          context.read<ItemsCacheProvider>(),
          context.read<ExpiryProvider>(),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SettingsCubit, SettingsState>(
      listener: (BuildContext context, SettingsState state) {
        if (state.errorMessage != null &&
            state.action == SettingsAction.restore) {
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
            state.isWorking && state.action == SettingsAction.restore;
        final bool justImported = state.status == SettingsStatus.success &&
            state.action == SettingsAction.restore &&
            state.lastImportSummary != null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('استيراد من إكسل', style: AppTextStyles.label),
            const SizedBox(height: 6),
            const Text(
              'يجلب عملاء وموردين وأنواع أصناف وسيارات من ملف .xlsx ويرفعها '
              'إلى النظام وقاعدة البيانات المشتركة معاً.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'استيراد من إكسل',
              icon: Icons.file_upload_outlined,
              isLoading: isWorking,
              onPressed: () => _import(context),
            ),
            if (justImported && state.message != null) ...<Widget>[
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
