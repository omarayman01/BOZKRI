import 'package:flutter/material.dart';

import '../../../../model/payment_model.dart';
import '../../../../view_model/utils/currency_formatter.dart';
import '../../../../view_model/utils/date_utils.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_text_styles.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/widgets/app_data_table.dart';

/// Payments made to this supplier (party = supplier, supplierId = this).
class SupplierPaymentsTab extends StatelessWidget {
  const SupplierPaymentsTab({super.key, required this.payments});

  final List<PaymentModel> payments;

  static String methodLabel(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'كاش';
      case PaymentMethod.mobileWallet:
        return 'محفظة';
      case PaymentMethod.instapay:
        return 'انستاباي';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDataTable(
      emptyTitle: 'No payments recorded yet',
      emptyMessage: 'Payments made to this supplier will appear here.',
      emptyIcon: Icons.payments_outlined,
      columns: const <DataColumn>[
        DataColumn(label: Text('التاريخ')),
        DataColumn(label: Text('الصفقة')),
        DataColumn(label: Text('طريقة الدفع')),
        DataColumn(label: Text('المبلغ')),
        DataColumn(label: Text('ملاحظات')),
      ],
      rows: payments.map((PaymentModel p) {
        return DataRow(
          onSelectChanged: (_) => Navigator.of(context)
              .pushNamed(AppRoutes.dealDetail, arguments: p.transactionId),
          cells: <DataCell>[
            DataCell(Text(
              AppDateUtils.formatDate(p.dateTime),
              style: AppTextStyles.tableCell,
              textDirection: TextDirection.ltr,
            )),
            DataCell(Text('#${p.transactionId}',
                style: AppTextStyles.tableCell,
                textDirection: TextDirection.ltr)),
            DataCell(Text(methodLabel(p.method), style: AppTextStyles.tableCell)),
            DataCell(Text(
              CurrencyFormatter.format(p.amount),
              style: AppTextStyles.money.copyWith(color: AppColors.success),
              textDirection: TextDirection.ltr,
            )),
            DataCell(Text(p.notes ?? '—', style: AppTextStyles.tableCell)),
          ],
        );
      }).toList(),
    );
  }
}
