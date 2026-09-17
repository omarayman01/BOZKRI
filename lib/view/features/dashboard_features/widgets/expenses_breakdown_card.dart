import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../model/expense_model.dart';
import '../../../../view_model/utils/currency_formatter.dart';
import '../../../../view_model/utils/date_utils.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_text_styles.dart';

/// Read-only itemized expenses for the dashboard's selected range, each with
/// its ملاحظات visible inline — editing still happens on the Expenses tab.
class ExpensesBreakdownCard extends StatelessWidget {
  const ExpensesBreakdownCard({super.key, required this.expenses});

  final List<ExpenseModel> expenses;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.expenses, style: AppTextStyles.title),
          const SizedBox(height: 12),
          if (expenses.isEmpty)
            Text(l10n.expensesEmptyMessage, style: AppTextStyles.caption)
          else
            ...expenses.map(
              (ExpenseModel e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(e.title, style: AppTextStyles.tableCell),
                        ),
                        if (e.categoryName != null) ...<Widget>[
                          Text(e.categoryName!, style: AppTextStyles.caption),
                          const SizedBox(width: 12),
                        ],
                        Text(
                          CurrencyFormatter.format(e.amount),
                          style: AppTextStyles.money,
                          textDirection: TextDirection.ltr,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          AppDateUtils.formatDate(e.dateTime),
                          style: AppTextStyles.caption,
                          textDirection: TextDirection.ltr,
                        ),
                      ],
                    ),
                    if (e.note != null && e.note!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(top: 2),
                        child: Text(
                          e.note!,
                          style: AppTextStyles.caption
                              .copyWith(fontStyle: FontStyle.italic),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const Divider(height: 14),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
