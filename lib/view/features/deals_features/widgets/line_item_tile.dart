import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../model/transaction_item_model.dart';
import '../../../../model/transaction_model.dart';
import '../../../../view_model/provider/expiry_provider.dart';
import '../../../../view_model/utils/currency_formatter.dart';
import '../../../../view_model/utils/date_utils.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_constants.dart';
import '../../../constants/app_text_styles.dart';
import '../../suppliers_features/widgets/expiry_badge.dart';

/// Read-only presentation of a committed deal line, used on the deal detail
/// screen. All figures come from the stored snapshots.
class LineItemTile extends StatelessWidget {
  const LineItemTile({super.key, required this.line});

  final TransactionItemModel line;

  @override
  Widget build(BuildContext context) {
    final ExpiryProvider expiry = context.watch<ExpiryProvider>();

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(line.itemLabel ?? 'عنصر رقم ${line.itemId}',
                    style: AppTextStyles.title),
              ),
              if (line.isPerDay) ...<Widget>[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: line.isReturned
                        ? AppColors.surface
                        : AppColors.successSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: (line.isReturned
                              ? AppColors.textSecondary
                              : AppColors.success)
                          .withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    line.isReturned ? 'مغلق' : 'ساري',
                    style: AppTextStyles.caption.copyWith(
                      color: line.isReturned
                          ? AppColors.textSecondary
                          : AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              if (line.refundedQty > 0)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 10),
                  child: Text(
                    'مرتجع ${line.refundedQty}/${line.qty}',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.warning),
                    textDirection: TextDirection.ltr,
                  ),
                ),
              if (line.expiryDate != null)
                ExpiryBadge(
                  level: expiry.levelForLine(line),
                  daysRemaining: expiry.daysRemaining(line.expiryDate),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${line.supplierName ?? 'المورد'} · ${_dealTypeLabel(context, line.dealType)}',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 28,
            runSpacing: 12,
            children: <Widget>[
              if (line.isPerDay) ...<Widget>[
                _Figure(
                    label: 'المده باليوم', value: CurrencyFormatter.number(line.days ?? 0)),
                _Figure(
                  label: 'سعر المعرض',
                  value: CurrencyFormatter.format(line.costPerDay ?? 0),
                ),
                _Figure(
                  label: 'السعر اليوم',
                  value: CurrencyFormatter.format(line.pricePerDay ?? 0),
                ),
              ] else ...<Widget>[
                _Figure(
                    label: 'الكمية', value: CurrencyFormatter.number(line.qty)),
                _Figure(
                  label: 'سعر الوحدة (التكلفة)',
                  value: CurrencyFormatter.format(line.unitCost),
                ),
                _Figure(
                  label: 'سعر الوحدة (البيع)',
                  value: CurrencyFormatter.format(line.unitPrice),
                ),
              ],
              _Figure(
                label: 'الاجمالي',
                value: CurrencyFormatter.format(line.lineTotal),
              ),
              _Figure(
                label: 'صافي الربح',
                value: CurrencyFormatter.signed(line.lineProfit),
                color: line.lineProfit >= 0
                    ? AppColors.success
                    : AppColors.danger,
              ),
              if (line.rentStart != null || line.rentEnd != null)
                _Figure(
                  label: 'فترة الإيجار',
                  value: '${AppDateUtils.formatNullable(line.rentStart)}'
                      ' → ${AppDateUtils.formatNullable(line.rentEnd)}',
                ),
              if (line.expiryDate != null)
                _Figure(
                  label: 'تاريخ الانتهاء',
                  value: AppDateUtils.formatDate(line.expiryDate!),
                ),
            ],
          ),
          if (line.notes?.isNotEmpty == true) ...<Widget>[
            const SizedBox(height: 12),
            Text(line.notes!, style: AppTextStyles.bodyMuted),
          ],
        ],
      ),
    );
  }
}

String _dealTypeLabel(BuildContext context, DealType type) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  switch (type) {
    case DealType.sell:
      return l10n.dealTypeSell;
    case DealType.rent:
      return l10n.dealTypeRent;
    case DealType.broker:
      return l10n.dealTypeBroker;
    case DealType.service:
      return l10n.dealTypeService;
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.money.copyWith(color: color),
          textDirection: TextDirection.ltr,
        ),
      ],
    );
  }
}
