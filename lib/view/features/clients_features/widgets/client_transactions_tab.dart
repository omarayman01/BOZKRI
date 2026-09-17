import 'package:flutter/material.dart';

import '../../../../model/transaction_model.dart';
import '../../../../view_model/utils/currency_formatter.dart';
import '../../../../view_model/utils/date_utils.dart';
import '../../../constants/app_text_styles.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/widgets/app_data_table.dart';
import '../../../core/widgets/payment_status_chip.dart';

/// Deals belonging to one client.
class ClientTransactionsTab extends StatelessWidget {
  const ClientTransactionsTab({super.key, required this.transactions});

  final List<TransactionModel> transactions;

  @override
  Widget build(BuildContext context) {
    return AppDataTable(
      emptyTitle: 'No deals yet',
      emptyMessage: 'Deals created for this client will appear here.',
      emptyIcon: Icons.receipt_long_outlined,
      columns: const <DataColumn>[
        DataColumn(label: Text('التاريخ')),
        DataColumn(label: Text('الصفقة')),
        DataColumn(label: Text('النوع')),
        DataColumn(label: Text('الاجمالي')),
        DataColumn(label: Text('التكلفة')),
        DataColumn(label: Text('صافي الربح')),
        DataColumn(label: Text('الحالة')),
      ],
      rows: transactions.map((TransactionModel t) {
        return DataRow(
          onSelectChanged: (_) => Navigator.of(context)
              .pushNamed(AppRoutes.dealDetail, arguments: t.id),
          cells: <DataCell>[
            DataCell(Text(
              AppDateUtils.formatDate(t.dateTime),
              style: AppTextStyles.tableCell,
              textDirection: TextDirection.ltr,
            )),
            DataCell(Text('#${t.id}',
                style: AppTextStyles.tableCell,
                textDirection: TextDirection.ltr)),
            DataCell(Text(t.dealType.name, style: AppTextStyles.tableCell)),
            DataCell(Text(
              CurrencyFormatter.format(t.total),
              style: AppTextStyles.money,
              textDirection: TextDirection.ltr,
            )),
            DataCell(Text(
              CurrencyFormatter.format(t.totalCost),
              style: AppTextStyles.money,
              textDirection: TextDirection.ltr,
            )),
            DataCell(Text(
              CurrencyFormatter.signed(t.grossProfit),
              style: AppTextStyles.profit(t.grossProfit),
              textDirection: TextDirection.ltr,
            )),
            DataCell(DealStatusChip(status: t.status, compact: true)),
          ],
        );
      }).toList(),
    );
  }
}
