import 'package:flutter/material.dart';

import '../../../../model/top_party_model.dart';
import '../../../../view_model/utils/currency_formatter.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_constants.dart';
import '../../../constants/app_text_styles.dart';
import '../../../core/navigation/app_routes.dart';

/// Ranked clients by net billed revenue inside the selected range.
class TopClientsList extends StatelessWidget {
  const TopClientsList({super.key, required this.clients});

  final List<TopPartyModel> clients;

  @override
  Widget build(BuildContext context) {
    return TopPartyPanel(
      title: 'أفضل العملاء',
      icon: Icons.people_outline,
      parties: clients,
      valueLabel: 'Billed',
      onTap: (TopPartyModel p) => Navigator.of(context)
          .pushNamed(AppRoutes.clientDetail, arguments: p.id),
    );
  }
}

/// Shared panel used by both top-party lists.
class TopPartyPanel extends StatelessWidget {
  const TopPartyPanel({
    super.key,
    required this.title,
    required this.icon,
    required this.parties,
    required this.valueLabel,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final List<TopPartyModel> parties;
  final String valueLabel;
  final ValueChanged<TopPartyModel> onTap;

  @override
  Widget build(BuildContext context) {
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
              Icon(icon, size: 18, color: AppColors.secondary),
              const SizedBox(width: 10),
              Text(title, style: AppTextStyles.title),
            ],
          ),
          const SizedBox(height: 14),
          if (parties.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text('Nothing in this period',
                  style: AppTextStyles.bodyMuted),
            )
          else
            for (int i = 0; i < parties.length; i++)
              InkWell(
                onTap: () => onTap(parties[i]),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 22,
                        child: Text(
                          '${i + 1}',
                          style: AppTextStyles.caption,
                          textDirection: TextDirection.ltr,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          parties[i].name,
                          style: AppTextStyles.body,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Text(
                            CurrencyFormatter.format(parties[i].total),
                            style: AppTextStyles.money,
                            textDirection: TextDirection.ltr,
                          ),
                          Text(
                            CurrencyFormatter.signed(parties[i].profit),
                            style: AppTextStyles.caption.copyWith(
                              color: parties[i].profit >= 0
                                  ? AppColors.success
                                  : AppColors.danger,
                            ),
                            textDirection: TextDirection.ltr,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
