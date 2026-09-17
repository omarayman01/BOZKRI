import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../model/payment_model.dart';
import '../../../../view_model/utils/currency_formatter.dart';
import '../../../../view_model/utils/date_utils.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_text_styles.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/widgets/app_data_table.dart';
import '../../suppliers_features/widgets/supplier_payments_tab.dart';

/// Read-only cash-out visibility: supplier payments for the selected range.
/// These rows are a view onto `payments`, not a separate ledger — no
/// add/edit/delete here, and never summed into the expenses total that
/// feeds net profit (that cost is already counted once as COGS).
class SupplierPaymentsSection extends StatelessWidget {
  const SupplierPaymentsSection({super.key, required this.payments});

  final List<PaymentModel> payments;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(l10n.supplierPayments, style: AppTextStyles.title),
        const SizedBox(height: 12),
        SizedBox(
          height: 260,
          child: AppDataTable(
            emptyTitle: l10n.supplierPayments,
            emptyMessage: l10n.supplierPaymentsEmptyMessage,
            emptyIcon: Icons.local_shipping_outlined,
            columns: const <DataColumn>[
              DataColumn(label: Text('التاريخ')),
              DataColumn(label: Text('المورد')),
              DataColumn(label: Text('الصفقة')),
              DataColumn(label: Text('طريقة الدفع')),
              DataColumn(label: Text('المبلغ')),
            ],
            rows: payments.map((PaymentModel p) {
              return DataRow(
                onSelectChanged: (_) => Navigator.of(context).pushNamed(
                  AppRoutes.dealDetail,
                  arguments: p.transactionId,
                ),
                cells: <DataCell>[
                  DataCell(Text(
                    AppDateUtils.formatDate(p.dateTime),
                    style: AppTextStyles.tableCell,
                    textDirection: TextDirection.ltr,
                  )),
                  DataCell(Text(p.supplierName ?? '—',
                      style: AppTextStyles.tableCell)),
                  DataCell(Text('#${p.transactionId}',
                      style: AppTextStyles.tableCell,
                      textDirection: TextDirection.ltr)),
                  DataCell(Text(SupplierPaymentsTab.methodLabel(p.method),
                      style: AppTextStyles.tableCell)),
                  DataCell(Text(
                    CurrencyFormatter.format(p.amount),
                    style: AppTextStyles.money.copyWith(color: AppColors.success),
                    textDirection: TextDirection.ltr,
                  )),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
