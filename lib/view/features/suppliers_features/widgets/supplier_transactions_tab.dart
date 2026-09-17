import 'package:flutter/material.dart';

import '../../../../model/payment_model.dart';
import '../../../../view_model/database/local/daos/suppliers_dao.dart';
import '../../../../view_model/utils/currency_formatter.dart';
import '../../../../view_model/utils/date_utils.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_text_styles.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/widgets/app_data_table.dart';
import '../../../core/widgets/payment_status_chip.dart';

/// Deals containing a line from this supplier, showing only this supplier's
/// cost slice — never the whole deal's totalCost.
class SupplierTransactionsTab extends StatelessWidget {
  const SupplierTransactionsTab({super.key, required this.slices});

  final List<SupplierTransactionSlice> slices;

  @override
  Widget build(BuildContext context) {
    return AppDataTable(
      emptyTitle: 'No deals yet',
      emptyMessage: 'Deals using this supplier\'s items will appear here.',
      emptyIcon: Icons.receipt_long_outlined,
      columns: const <DataColumn>[
        DataColumn(label: Text('التاريخ')),
        DataColumn(label: Text('الصفقة')),
        DataColumn(label: Text('العميل')),
        DataColumn(label: Text('تكلفتك')),
        DataColumn(label: Text('المدفوع')),
        DataColumn(label: Text('المتبقي')),
        DataColumn(label: Text('الحالة')),
      ],
      rows: slices.map((SupplierTransactionSlice slice) {
        return DataRow(
          onSelectChanged: (_) => Navigator.of(context).pushNamed(
            AppRoutes.dealDetail,
            arguments: slice.transaction.id,
          ),
          cells: <DataCell>[
            DataCell(Text(
              AppDateUtils.formatDate(slice.transaction.dateTime),
              style: AppTextStyles.tableCell,
              textDirection: TextDirection.ltr,
            )),
            DataCell(Text('#${slice.transaction.id}',
                style: AppTextStyles.tableCell,
                textDirection: TextDirection.ltr)),
            DataCell(Text(slice.transaction.clientName ?? '—',
                style: AppTextStyles.tableCell)),
            DataCell(Text(
              CurrencyFormatter.format(slice.supplierCost),
              style: AppTextStyles.money,
              textDirection: TextDirection.ltr,
            )),
            DataCell(Text(
              CurrencyFormatter.format(slice.supplierPaid),
              style: AppTextStyles.money.copyWith(color: AppColors.success),
              textDirection: TextDirection.ltr,
            )),
            DataCell(Text(
              CurrencyFormatter.format(slice.outstanding),
              style: AppTextStyles.money.copyWith(
                color: slice.outstanding > 0.005
                    ? AppColors.danger
                    : AppColors.success,
              ),
              textDirection: TextDirection.ltr,
            )),
            DataCell(PaymentStatusChip(
              status: _statusFor(slice),
              compact: true,
            )),
          ],
        );
      }).toList(),
    );
  }

  static PaymentStatus _statusFor(SupplierTransactionSlice slice) {
    if (slice.supplierCost <= 0.005) return PaymentStatus.paid;
    if (slice.supplierPaid <= 0.005) return PaymentStatus.unpaid;
    if (slice.supplierPaid >= slice.supplierCost - 0.005) {
      return PaymentStatus.paid;
    }
    return PaymentStatus.partial;
  }
}
