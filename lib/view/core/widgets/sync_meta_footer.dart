import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../view_model/provider/user_directory_provider.dart';
import '../../../view_model/utils/date_utils.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';

/// Small "أضيف … — آخر تحديث … بواسطة …" line shown at the bottom of a
/// record's detail/edit screen — created/updated timestamps plus who made
/// the last change, resolved from the synced `updatedBy` uuid via
/// [UserDirectoryProvider].
class SyncMetaFooter extends StatelessWidget {
  const SyncMetaFooter({
    super.key,
    required this.createdAt,
    this.updatedAt,
    this.updatedBy,
  });

  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? updatedBy;

  @override
  Widget build(BuildContext context) {
    final String? updatedByName =
        context.watch<UserDirectoryProvider>().nameFor(updatedBy);

    final List<String> parts = <String>[
      'أضيف: ${AppDateUtils.formatDateTime(createdAt)}',
    ];
    if (updatedAt != null) {
      final String who = updatedByName != null ? ' بواسطة $updatedByName' : '';
      parts.add('آخر تحديث: ${AppDateUtils.formatDateTime(updatedAt!)}$who');
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: <Widget>[
          const Icon(Icons.history, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              parts.join('  •  '),
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
