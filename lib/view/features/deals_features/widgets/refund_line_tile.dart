import 'package:flutter/material.dart';

import '../../../../model/transaction_item_model.dart';
import '../../../../view_model/utils/currency_formatter.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_constants.dart';
import '../../../constants/app_text_styles.dart';

/// One refundable deal line with a quantity stepper capped at the remaining
/// refundable amount (original qty − already refunded).
class RefundLineTile extends StatelessWidget {
  const RefundLineTile({
    super.key,
    required this.line,
    required this.alreadyRefunded,
    required this.selectedQty,
    required this.onQtyChanged,
  });

  final TransactionItemModel line;
  final int alreadyRefunded;
  final int selectedQty;
  final ValueChanged<int> onQtyChanged;

  int get refundable => line.qty - alreadyRefunded;

  @override
  Widget build(BuildContext context) {
    final bool exhausted = refundable <= 0;

    return Opacity(
      opacity: exhausted ? 0.55 : 1,
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppConstants.cardRadius),
          border: Border.all(
            color: selectedQty > 0 ? AppColors.warning : AppColors.border,
          ),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(line.itemLabel ?? 'Item #${line.itemId}',
                      style: AppTextStyles.subtitle),
                  const SizedBox(height: 4),
                  Text(
                    '${line.supplierName ?? 'Supplier'} · '
                    'unit ${CurrencyFormatter.format(line.unitPrice)} · '
                    'cost ${CurrencyFormatter.format(line.unitCost)}',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    exhausted
                        ? 'Fully refunded'
                        : 'Refundable: $refundable of ${line.qty}',
                    style: AppTextStyles.caption.copyWith(
                      color: exhausted ? AppColors.danger : AppColors.secondary,
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                ],
              ),
            ),
            if (!exhausted) ...<Widget>[
              IconButton(
                tooltip: 'أقل',
                onPressed: selectedQty <= 0
                    ? null
                    : () => onQtyChanged(selectedQty - 1),
                icon: const Icon(Icons.remove_circle_outline, size: 20),
              ),
              SizedBox(
                width: 34,
                child: Text(
                  '$selectedQty',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.money,
                  textDirection: TextDirection.ltr,
                ),
              ),
              IconButton(
                tooltip: 'أكثر',
                onPressed: selectedQty >= refundable
                    ? null
                    : () => onQtyChanged(selectedQty + 1),
                icon: const Icon(Icons.add_circle_outline, size: 20),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 120,
                child: Text(
                  CurrencyFormatter.format(line.unitPrice * selectedQty),
                  textAlign: TextAlign.end,
                  style: AppTextStyles.money.copyWith(
                    color: selectedQty > 0 ? AppColors.warning : null,
                  ),
                  textDirection: TextDirection.ltr,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
