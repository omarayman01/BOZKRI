import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_text_styles.dart';

/// Headline figure card used on the dashboard and the party balance cards.
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.caption,
    this.valueColor,
    this.accent,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;
  final String? caption;
  final Color? valueColor;

  /// Tints the icon chip; defaults to the secondary brand colour.
  final Color? accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color tint = accent ?? AppColors.secondary;

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppConstants.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.cardRadius),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: tint.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 17, color: tint),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      style: AppTextStyles.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: AppTextStyles.moneyLarge
                    .copyWith(color: valueColor ?? AppColors.deepNavy),
                textDirection: TextDirection.ltr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (caption != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(caption!, style: AppTextStyles.caption),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
