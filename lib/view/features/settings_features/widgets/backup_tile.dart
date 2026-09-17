import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../view_model/cubit/settings/settings_cubit.dart';
import '../../../../view_model/cubit/settings/settings_state.dart';
import '../../../../view_model/utils/db_backup_helper.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_text_styles.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/primary_button.dart';

/// "حفظ نسخة احتياطية" — one primary action. The admin either browses to a
/// destination folder or types/pastes an absolute path; either way, both a
/// `.sqlite` backup and a matching `.xlsx` report are written there.
class BackupTile extends StatefulWidget {
  const BackupTile({super.key});

  @override
  State<BackupTile> createState() => _BackupTileState();
}

class _BackupTileState extends State<BackupTile> {
  final TextEditingController _path = TextEditingController();

  @override
  void dispose() {
    _path.dispose();
    super.dispose();
  }

  Future<void> _browse() async {
    final String? folder = await DbBackupHelper.pickBackupDestinationFolder();
    if (folder != null) setState(() => _path.text = folder);
  }

  Future<void> _save(BuildContext context) async {
    final bool ok = await ConfirmDialog.show(
      context,
      title: 'حفظ نسخة احتياطية؟',
      message: 'سيتم إغلاق قاعدة البيانات مؤقتاً لكتابة الملفات بأمان، ثم '
          'إعادة فتحها. يجب إعادة تشغيل التطبيق بعد اكتمال الحفظ.',
      confirmLabel: 'حفظ',
    );
    if (!ok || !context.mounted) return;

    final String typed = _path.text.trim();
    await context
        .read<SettingsCubit>()
        .backup(typedPath: typed.isEmpty ? null : typed);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SettingsCubit, SettingsState>(
      listener: (BuildContext context, SettingsState state) {
        if (state.errorMessage != null && state.action == SettingsAction.backup) {
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
            state.isWorking && state.action == SettingsAction.backup;
        final bool justSaved = state.status == SettingsStatus.success &&
            state.action == SettingsAction.backup;
        // Any earlier backup or .sqlite restore this session already closed
        // the live database connection for good (Drift connections cannot
        // be reopened) — every further action here would hit a raw,
        // English "Bad state" exception, so both actions are disabled until
        // the admin restarts the app.
        final bool disabledForRestart = state.requiresRestart;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('حفظ نسخة احتياطية', style: AppTextStyles.label),
            const SizedBox(height: 6),
            const Text(
              'يكتب نسخة احتياطية كاملة (.sqlite) وتقرير إكسل (.xlsx) في '
              'مجلد تختاره أو مسار تكتبه.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: AppTextField(
                    label: 'اختر مجلداً أو أدخل مساراً',
                    controller: _path,
                    enabled: !disabledForRestart,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: disabledForRestart ? null : _browse,
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: const Text('استعراض'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'حفظ نسخة احتياطية',
              icon: Icons.save_alt,
              isLoading: isWorking,
              onPressed: disabledForRestart ? null : () => _save(context),
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
