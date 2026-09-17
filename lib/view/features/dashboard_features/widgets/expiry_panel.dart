import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../model/item_model.dart';
import '../../../../view_model/provider/expiry_provider.dart';
import '../../../../view_model/utils/date_utils.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_constants.dart';
import '../../../constants/app_text_styles.dart';
import '../../../core/navigation/app_routes.dart';
import '../../suppliers_features/widgets/expiry_badge.dart';

/// Items that are expired or fall inside the configured warning window,
/// straight from [ExpiryProvider].
class ExpiryPanel extends StatelessWidget {
  const ExpiryPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final ExpiryProvider expiry = context.watch<ExpiryProvider>();
    final List<ItemModel> flagged = expiry.flaggedItems;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.schedule,
                  size: 18, color: AppColors.secondary),
              const SizedBox(width: 10),
              Text('Expiring soon', style: AppTextStyles.title),
              const Spacer(),
              Text(
                'within ${expiry.warningDays}d',
                style: AppTextStyles.caption,
                textDirection: TextDirection.ltr,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (flagged.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'No items fall inside the warning window.',
                style: AppTextStyles.bodyMuted,
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: flagged.length,
                itemBuilder: (BuildContext context, int index) {
                  final ItemModel item = flagged[index];
                  return InkWell(
                    onTap: () => Navigator.of(context).pushNamed(
                      AppRoutes.supplierDetail,
                      arguments: item.supplierId,
                    ),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  item.label,
                                  style: AppTextStyles.body,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${item.supplierName ?? ''} · '
                                  '${AppDateUtils.formatNullable(item.expiryDate)}',
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                          ),
                          ExpiryBadge(
                            level: expiry.levelForItem(item),
                            daysRemaining:
                                expiry.daysRemaining(item.expiryDate),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
