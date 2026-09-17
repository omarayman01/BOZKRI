import 'package:flutter/material.dart';

import '../../../../model/party_balance_model.dart';
import '../../../../view_model/utils/currency_formatter.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_constants.dart';
import '../../../constants/app_text_styles.dart';
import '../../../core/widgets/payment_status_chip.dart';

/// Derived payable for one supplier: the sum of their own line costs net of
/// refunded cost, minus payments attributed to them.
class SupplierBalanceCard extends StatelessWidget {
  const SupplierBalanceCard({super.key, required this.balance});

  final PartyBalanceModel balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
              const Icon(Icons.request_quote_outlined,
                  size: 18, color: AppColors.secondary),
              const SizedBox(width: 10),
              Text('Payable', style: AppTextStyles.label),
              const Spacer(),
              PaymentStatusChip(status: balance.status),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 40,
            runSpacing: 16,
            children: <Widget>[
              _Figure(
                label: 'إجمالي المستحق',
                value: CurrencyFormatter.format(balance.totalOwed),
              ),
              _Figure(
                label: 'المدفوع',
                value: CurrencyFormatter.format(balance.totalSettled),
                color: AppColors.success,
              ),
              _Figure(
                label: 'المتبقي',
                value: CurrencyFormatter.format(balance.outstanding),
                color: balance.outstanding > 0
                    ? AppColors.danger
                    : AppColors.success,
                emphasise: true,
              ),
              _Figure(
                label: 'الصفقات',
                value: CurrencyFormatter.number(balance.transactionCount),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    this.color,
    this.emphasise = false,
  });

  final String label;
  final String value;
  final Color? color;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 4),
        Text(
          value,
          textDirection: TextDirection.ltr,
          style: (emphasise ? AppTextStyles.moneyLarge : AppTextStyles.money)
              .copyWith(color: color),
        ),
      ],
    );
  }
}
