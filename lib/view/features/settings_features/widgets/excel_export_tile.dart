import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../view_model/cubit/settings/settings_cubit.dart';
import '../../../../view_model/cubit/settings/settings_state.dart';
import '../../../../view_model/utils/db_backup_helper.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';

/// "حفظ البيانات في إكسل" — a lightweight export: just the `.xlsx` report,
/// no `.sqlite` file, no closing the database, no app restart. Separate
/// from the full "حفظ نسخة احتياطية" action above, which is heavier and
/// meant for real backups rather than a quick spreadsheet copy.
class ExcelExportTile extends StatelessWidget {
  const ExcelExportTile({super.key});

  Future<void> _save(BuildContext context) async {
    final String? folder = await DbBackupHelper.pickBackupDestinationFolder();
    if (folder == null || !context.mounted) return;
    await context.read<SettingsCubit>().exportExcel(typedPath: folder);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SettingsCubit, SettingsState>(
      listener: (BuildContext context, SettingsState state) {
        if (state.errorMessage != null &&
            state.action == SettingsAction.excelExport) {
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
            state.isWorking && state.action == SettingsAction.excelExport;
        final bool justSaved = state.status == SettingsStatus.success &&
            state.action == SettingsAction.excelExport;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('حفظ البيانات في إكسل', style: AppTextStyles.label),
            const SizedBox(height: 6),
            const Text(
              'يكتب تقرير إكسل (.xlsx) فقط بكل البيانات الحالية — لا يغلق '
              'قاعدة البيانات ولا يحتاج إعادة تشغيل التطبيق.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'حفظ في إكسل',
              icon: Icons.grid_on_outlined,
              isLoading: isWorking,
              onPressed: () => _save(context),
            ),
            if (justSaved && state.message != null) ...<Widget>[
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
                      child: Text(
                        state.message!,
                        style: AppTextStyles.caption,
                        textDirection: TextDirection.ltr,
                      ),
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
