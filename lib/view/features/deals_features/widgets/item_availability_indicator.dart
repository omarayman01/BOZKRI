import 'package:flutter/material.dart';

import '../../../../model/item_model.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_text_styles.dart';

/// Shows whether a single-use item is still available. Reusable items are
/// labelled as such since availability is not enforced for them.
class ItemAvailabilityIndicator extends StatelessWidget {
  const ItemAvailabilityIndicator({
    super.key,
    required this.isSingleUse,
    required this.isAvailable,
  });

  factory ItemAvailabilityIndicator.forItem(ItemModel item) =>
      ItemAvailabilityIndicator(
        isSingleUse: item.isSingleUse,
        isAvailable: item.isAvailable,
      );

  final bool isSingleUse;
  final bool isAvailable;

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final IconData icon;
    late final Color color;
    late final Color background;

    if (!isSingleUse) {
      label = 'قابل لإعادة الاستخدام';
      icon = Icons.all_inclusive;
      color = AppColors.primary;
      background = AppColors.surface;
    } else if (isAvailable) {
      label = 'متاح';
      icon = Icons.check_circle_outline;
      color = AppColors.success;
      background = AppColors.successSurface;
    } else {
      label = 'مستخدم';
      icon = Icons.block;
      color = AppColors.danger;
      background = AppColors.dangerSurface;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.caption
                .copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
