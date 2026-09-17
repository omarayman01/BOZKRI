import 'package:flutter/material.dart';

import '../../../../model/supplier_model.dart';
import '../../../../view_model/utils/date_utils.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_text_styles.dart';

/// One row of the suppliers data table.
class SupplierRow {
  const SupplierRow._();

  static List<DataColumn> columns() => const <DataColumn>[
        DataColumn(label: Text('الاسم')),
        DataColumn(label: Text('الهاتف')),
        DataColumn(label: Text('تاريخ الاضافة')),
        DataColumn(label: Text('الحالة')),
        DataColumn(label: Text('')),
      ];

  static DataRow build(
    SupplierModel supplier, {
    required VoidCallback onOpen,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    final Color statusColor =
        supplier.isActive ? AppColors.success : AppColors.textDisabled;

    return DataRow(
      onSelectChanged: (_) => onOpen(),
      cells: <DataCell>[
        DataCell(Text(supplier.name, style: AppTextStyles.tableCell)),
        DataCell(Text(
          supplier.phone?.isNotEmpty == true ? supplier.phone! : '—',
          style: AppTextStyles.tableCell,
          textDirection: TextDirection.ltr,
        )),
        DataCell(Text(
          AppDateUtils.formatDate(supplier.createdAt),
          style: AppTextStyles.tableCell,
          textDirection: TextDirection.ltr,
        )),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: statusColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              supplier.isActive ? 'نشط' : 'غير نشط',
              style: AppTextStyles.caption.copyWith(color: statusColor),
            ),
          ],
        )),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              tooltip: 'تعديل',
              icon: const Icon(Icons.edit_outlined, size: 18),
              color: AppColors.primary,
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: 'حذف',
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
