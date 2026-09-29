import 'package:flutter/material.dart';

import '../../../../model/audit_log_entry_model.dart';
import '../../../../view_model/utils/date_utils.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_constants.dart';
import '../../../constants/app_text_styles.dart';
import '../../../core/widgets/empty_state_widget.dart';

/// Read-only, append-only feed of who did what and when (Phase 22).
class AuditLogList extends StatelessWidget {
  const AuditLogList({super.key, required this.entries});

  final List<AuditLogEntryModel> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const EmptyStateWidget(
        title: 'لا يوجد نشاط بعد',
        icon: Icons.history,
      );
    }

    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (BuildContext context, int i) {
        final AuditLogEntryModel entry = entries[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppConstants.cardRadius),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(entry.summary, style: AppTextStyles.body),
                    const SizedBox(height: 4),
                    Text(
                      entry.userDisplayName ?? 'مستخدم محذوف',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                AppDateUtils.formatDateTime(entry.createdAt),
                style: AppTextStyles.caption,
              ),
            ],
          ),
        );
      },
    );
  }
}
