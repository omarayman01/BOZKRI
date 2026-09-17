import 'package:flutter/material.dart';

import '../../../../view_model/provider/expiry_provider.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_text_styles.dart';

/// Red when expired, amber when inside the warning window, nothing otherwise.
class ExpiryBadge extends StatelessWidget {
  const ExpiryBadge({
    super.key,
    required this.level,
    this.daysRemaining,
    this.compact = true,
  });

  final ExpiryLevel level;
  final int? daysRemaining;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (level == ExpiryLevel.none) return const SizedBox.shrink();

    final bool expired = level == ExpiryLevel.expired;
    final Color foreground = expired ? AppColors.danger : AppColors.warning;
    final Color background =
        expired ? AppColors.dangerSurface : AppColors.warningSurface;

    final String label = expired
        ? (daysRemaining == null
            ? 'منتهي'
            : 'منتهي منذ ${daysRemaining!.abs()} يوم')
        : (daysRemaining == null ? 'قريب الانتهاء' : 'خلال $daysRemaining يوم');

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: foreground.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            expired ? Icons.error_outline : Icons.schedule,
            size: 12,
            color: foreground,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
            textDirection: TextDirection.ltr,
          ),
        ],
      ),
    );
  }
}
