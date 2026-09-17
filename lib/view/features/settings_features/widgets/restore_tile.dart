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

/// "استرجاع البيانات" — one destructive-styled action. Opens a file picker
/// accepting `.sqlite` (full restore) or `.xlsx` (master-data-only import),
/// with a distinct confirmation per branch.
class RestoreTile extends StatelessWidget {
  const RestoreTile({super.key});

  Future<void> _restore(BuildContext context) async {
    final String? sourcePath = await DbBackupHelper.pickRestoreSourceFile();
    if (sourcePath == null || !context.mounted) return;

    final bool isSqlite = p.extension(sourcePath).toLowerCase() == '.sqlite';

    bool ok;
    if (isSqlite) {
      ok = await ConfirmDialog.show(
        context,
        title: 'استرجاع كامل من نسخة احتياطية؟',
        message: 'سيتم استبدال قاعدة البيانات الحالية بالكامل بملف '
            '${p.basename(sourcePath)}.',
        confirmLabel: 'استرجاع',
        isDestructive: true,
        warning: 'سيتم الاحتفاظ بنسخة أمان من قاعدة البيانات الحالية. '
            'أعد تشغيل التطبيق بعد الاستعادة.',
      );
    } else {
      if (!context.mounted) return;
      ok = await ConfirmDialog.show(
        context,
        title: 'استرجاع بيانات أساسية فقط؟',
        message: 'هذا الاستيراد يجلب العملاء والموردين وأنواع الأصناف '
            'وحقولها والأصناف/السيارات من ${p.basename(sourcePath)}.',
        confirmLabel: 'استيراد',
        warning: 'لا يجلب هذا الاستيراد الصفقات أو الدفعات أو الأرصدة — '
            'تبقى كما هي دون أي تغيير.',
      );
    }
    if (!context.mounted) return;
    if (!ok) return;

    await context.read<SettingsCubit>().restore(sourcePath: sourcePath);
    if (!context.mounted) return;

    // A .sqlite restore closes the live connection for good (the app must
    // restart before anything else can query it) — nothing to refresh. A
    // .xlsx import keeps the connection open and writes straight into the
    // clients/suppliers/items tables, so every list screen and cache-backed
    // picker must be reloaded here or the admin would only see the newly
    // imported rows after restarting the app.
    if (!isSqlite) {
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
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SettingsCubit, SettingsState>(
      listener: (BuildContext context, SettingsState state) {
        if (state.errorMessage != null && state.action == SettingsAction.restore) {
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
        final bool justRestored = state.status == SettingsStatus.success &&
            state.action == SettingsAction.restore;
        // Any earlier backup or .sqlite restore this session already closed
        // the live database connection for good (Drift connections cannot
        // be reopened) — every further action here would hit a raw,
        // English "Bad state" exception, so both actions are disabled until
        // the admin restarts the app.
        final bool disabledForRestart = state.requiresRestart;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('استرجاع البيانات', style: AppTextStyles.label),
            const SizedBox(height: 6),
            const Text(
              'اختر ملف .sqlite لاستعادة كاملة، أو ملف .xlsx لاستيراد بيانات '
              'أساسية فقط (عملاء وموردين وسيارات).',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'استرجاع البيانات',
              icon: Icons.settings_backup_restore,
              isDestructive: true,
              isLoading: isWorking,
              onPressed: disabledForRestart ? null : () => _restore(context),
            ),
            if (justRestored && state.message != null) ...<Widget>[
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
            if (disabledForRestart) ...<Widget>[
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  const Icon(Icons.restart_alt,
                      size: 18, color: AppColors.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'أعد تشغيل التطبيق لمتابعة العمل على قاعدة البيانات.',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
