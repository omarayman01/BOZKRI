import 'package:flutter/material.dart';

import '../../../../model/item_model.dart';
import '../../../../model/item_type_field_model.dart';
import '../../../../view_model/utils/dynamic_field_utils.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_text_styles.dart';

/// One car's cells: its dynamic fields (ماركة/موديل, رقم اللوحة, ...) plus
/// its assigned supplier and active state, mirroring `deal_row.dart`/
/// `expense_row.dart`'s per-column `DataCell` pattern.
///
/// [fields] is always the primary car item type's schema — shared across
/// every row so the table's column count stays consistent even if a car
/// belongs to a differently-configured car-category item type.
class CarRow {
  const CarRow._();

  static List<DataColumn> columns(List<ItemTypeFieldModel> fields) {
    return <DataColumn>[
      const DataColumn(label: Text('السيارة')),
      for (final ItemTypeFieldModel field in fields)
        DataColumn(label: Text(field.fieldName)),
      const DataColumn(label: Text('المورد')),
      const DataColumn(label: Text('وضع النشاط')),
      const DataColumn(label: Text('')),
    ];
  }

  static DataRow build(
    ItemModel car, {
    required List<ItemTypeFieldModel> fields,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    final Map<int, String> values = DynamicFieldUtils.toValueMap(car.fieldValues);

    return DataRow(
      onSelectChanged: (_) => onEdit(),
      cells: <DataCell>[
        DataCell(Text(car.label, style: AppTextStyles.tableCell)),
        for (final ItemTypeFieldModel field in fields)
          DataCell(Text(
            values[field.id] == null || values[field.id]!.trim().isEmpty
                ? '—'
                : DynamicFieldUtils.display(field.fieldType, values[field.id]!),
            style: AppTextStyles.tableCell,
          )),
        DataCell(Text(car.supplierName ?? '—', style: AppTextStyles.tableCell)),
        DataCell(_ActiveChip(isActive: car.isActive)),
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

class _ActiveChip extends StatelessWidget {
  const _ActiveChip({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final Color color = isActive ? AppColors.success : AppColors.danger;
    final Color background =
        isActive ? AppColors.successSurface : AppColors.dangerSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        isActive ? 'نشطة' : 'غير نشطة',
        style: AppTextStyles.caption
            .copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
