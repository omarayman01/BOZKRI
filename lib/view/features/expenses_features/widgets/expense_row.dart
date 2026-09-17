import 'package:flutter/material.dart';

import '../../../../model/expense_model.dart';
import '../../../../view_model/utils/currency_formatter.dart';
import '../../../../view_model/utils/date_utils.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_text_styles.dart';

/// One expense's cells, mirroring `deal_row.dart`'s per-column pattern.
class ExpenseRow {
  const ExpenseRow._();

  static DataRow build(
    ExpenseModel expense, {
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return DataRow(
      onSelectChanged: (_) => onEdit(),
      cells: <DataCell>[
        DataCell(Text(
          AppDateUtils.formatDate(expense.dateTime),
          style: AppTextStyles.tableCell,
          textDirection: TextDirection.ltr,
        )),
        DataCell(Text(expense.title, style: AppTextStyles.tableCell)),
        DataCell(Text(expense.categoryName ?? '—',
            style: AppTextStyles.tableCell)),
        DataCell(Text(
          CurrencyFormatter.format(expense.amount),
          style: AppTextStyles.money,
          textDirection: TextDirection.ltr,
        )),
        DataCell(Text(expense.note ?? '—', style: AppTextStyles.tableCell)),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              color: AppColors.primary,
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              color: AppColors.danger,
              onPressed: onDelete,
            ),
          ],
        )),
      ],
    );
  }
}
