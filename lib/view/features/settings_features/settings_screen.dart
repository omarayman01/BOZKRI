import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../view_model/cubit/settings/settings_cubit.dart';
import '../../../view_model/cubit/settings/settings_state.dart';
import '../../../view_model/provider/expiry_provider.dart';
import '../../../view_model/provider/settings_provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_text_styles.dart';
import '../../core/widgets/blocking_progress_overlay.dart';
import 'widgets/account_tile.dart';
import 'widgets/backup_tile.dart';
import 'widgets/excel_export_tile.dart';
import 'widgets/excel_import_tile.dart';
import 'widgets/item_types_manager.dart';
import 'widgets/reset_system_tile.dart';
import 'widgets/restore_tile.dart';

/// Currency, expiry window, item types and database backup.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  String? _statusText(AppLocalizations l10n, SettingsState state) {
    if (!state.isWorking) return null;
    switch (state.step) {
      case SettingsStep.resolvingDestination:
        return 'جاري تحديد الوجهة…';
      case SettingsStep.writingExcel:
        return l10n.savingExcel;
      case SettingsStep.writingSqlite:
        return l10n.savingSqlite;
      case SettingsStep.validatingBackup:
        return 'جاري التحقق من النسخة…';
      case SettingsStep.importingMasterData:
        return 'جاري استيراد البيانات الأساسية…';
      case SettingsStep.replacingDatabase:
        return 'جاري الاستبدال…';
      case SettingsStep.wiping:
        return 'جاري إعادة التعيين…';
      case SettingsStep.none:
        return l10n.loading;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (BuildContext context, SettingsState state) {
          return BlockingProgressOverlay(
            visible: state.isWorking,
            statusText: _statusText(l10n, state),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.contentPadding),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: const <Widget>[
                      _Section(child: AccountTile()),
                      SizedBox(height: 20),
                      _Section(child: _ExpiryWindowSetting()),
                      SizedBox(height: 20),
                      _Section(child: ItemTypesManager()),
                      SizedBox(height: 20),
                      _Section(child: ExcelExportTile()),
                      SizedBox(height: 20),
                      _Section(child: ExcelImportTile()),
                      SizedBox(height: 20),
                      _Section(child: BackupTile()),
                      SizedBox(height: 20),
                      _Section(child: RestoreTile()),
                      SizedBox(height: 20),
                      _Section(child: ResetSystemTile()),
                      SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

/// How many days before an expiry date an item is flagged amber.
class _ExpiryWindowSetting extends StatelessWidget {
  const _ExpiryWindowSetting();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final SettingsProvider settings = context.watch<SettingsProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l10n.expiryWindow, style: AppTextStyles.label),
        const SizedBox(height: 6),
        Text(l10n.expiryWindowDays, style: AppTextStyles.caption),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: Slider(
                value: settings.expiryWarningDays.toDouble().clamp(1, 180),
                min: 1,
                max: 180,
                divisions: 179,
                activeColor: AppColors.primary,
                label: '${settings.expiryWarningDays}',
                onChanged: (double value) => context
                    .read<SettingsCubit>()
                    .setExpiryWarningDays(
                      settings,
                      context.read<ExpiryProvider>(),
                      value.round(),
                    ),
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                '${settings.expiryWarningDays} يوم',
                style: AppTextStyles.money,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
