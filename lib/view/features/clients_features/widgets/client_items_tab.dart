import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../model/transaction_item_model.dart';
import '../../../../view_model/provider/expiry_provider.dart';
import '../../../../view_model/utils/currency_formatter.dart';
import '../../../../view_model/utils/date_utils.dart';
import '../../../constants/app_text_styles.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/widgets/app_data_table.dart';
import '../../suppliers_features/widgets/expiry_badge.dart';

/// Line items this client took, with the client-side expiry date.
class ClientItemsTab extends StatelessWidget {
  const ClientItemsTab({super.key, required this.items});

  final List<TransactionItemModel> items;

  @override
  Widget build(BuildContext context) {
    final ExpiryProvider expiry = context.watch<ExpiryProvider>();

    return AppDataTable(
      emptyTitle: 'No items yet',
      emptyMessage: 'Items taken by this client will appear here.',
      emptyIcon: Icons.inventory_2_outlined,
      columns: const <DataColumn>[
        DataColumn(label: Text('العنصر')),
        DataColumn(label: Text('المورد')),
        DataColumn(label: Text('الصفقة')),
        DataColumn(label: Text('الكمية')),
        DataColumn(label: Text('سعر الوحدة')),
        DataColumn(label: Text('تاريخ الانتهاء')),
      ],
      rows: items.map((TransactionItemModel line) {
        return DataRow(
          onSelectChanged: (_) => Navigator.of(context)
              .pushNamed(AppRoutes.dealDetail, arguments: line.transactionId),
          cells: <DataCell>[
            DataCell(Text(line.itemLabel ?? '—',
                style: AppTextStyles.tableCell)),
            DataCell(Text(line.supplierName ?? '—',
                style: AppTextStyles.tableCell)),
            DataCell(Text('#${line.transactionId}',
                style: AppTextStyles.tableCell,
                textDirection: TextDirection.ltr)),
            DataCell(Text(
              CurrencyFormatter.number(line.qty),
              style: AppTextStyles.tableCell,
              textDirection: TextDirection.ltr,
            )),
            DataCell(Text(
              CurrencyFormatter.format(line.unitPrice),
              style: AppTextStyles.money,
              textDirection: TextDirection.ltr,
            )),
            DataCell(
              line.expiryDate == null
                  ? Text('—', style: AppTextStyles.tableCell)
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          AppDateUtils.formatDate(line.expiryDate!),
                          style: AppTextStyles.tableCell,
                          textDirection: TextDirection.ltr,
                        ),
                        const SizedBox(width: 8),
                        ExpiryBadge(
                          level: expiry.levelForDate(line.expiryDate),
                          daysRemaining: expiry.daysRemaining(line.expiryDate),
                        ),
                      ],
                    ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
