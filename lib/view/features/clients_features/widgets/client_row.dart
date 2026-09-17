import 'package:flutter/material.dart';

import '../../../../model/client_model.dart';
import '../../../../view_model/utils/date_utils.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_text_styles.dart';

/// One row of the clients data table.
class ClientRow {
  const ClientRow._();

  static List<DataColumn> columns() => const <DataColumn>[
        DataColumn(label: Text('الاسم')),
        DataColumn(label: Text('الهاتف')),
        DataColumn(label: Text('تاريخ الاضافة')),
        DataColumn(label: Text('الحالة')),
        DataColumn(label: Text('')),
      ];

  static DataRow build(
    ClientModel client, {
    required VoidCallback onOpen,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return DataRow(
      onSelectChanged: (_) => onOpen(),
      cells: <DataCell>[
        DataCell(Text(client.name, style: AppTextStyles.tableCell)),
        DataCell(Text(
          client.phone?.isNotEmpty == true ? client.phone! : '—',
          style: AppTextStyles.tableCell,
          textDirection: TextDirection.ltr,
        )),
        DataCell(Text(
          AppDateUtils.formatDate(client.createdAt),
          style: AppTextStyles.tableCell,
          textDirection: TextDirection.ltr,
        )),
        DataCell(_StatusDot(isActive: client.isActive)),
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

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final Color color = isActive ? AppColors.success : AppColors.textDisabled;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          isActive ? 'نشط' : 'غير نشط',
          style: AppTextStyles.caption.copyWith(color: color),
        ),
      ],
    );
  }
}
