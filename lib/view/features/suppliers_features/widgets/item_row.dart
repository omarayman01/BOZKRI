import 'package:flutter/material.dart';

import '../../../../model/item_model.dart';
import '../../../../model/item_type_field_model.dart';
import '../../../../model/item_type_model.dart';
import '../../../../view_model/provider/expiry_provider.dart';
import '../../../../view_model/utils/currency_formatter.dart';
import '../../../../view_model/utils/date_utils.dart';
import '../../../../view_model/utils/dynamic_field_utils.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_text_styles.dart';
import 'expiry_badge.dart';

/// One row of the supplier's items table, including a compact summary of the
/// item's dynamic field values.
class ItemRow {
  const ItemRow._();

  static List<DataColumn> columns() => const <DataColumn>[
        DataColumn(label: Text('العنصر')),
        DataColumn(label: Text('الصنف')),
        DataColumn(label: Text('التفاصيل')),
        DataColumn(label: Text('التكلفة')),
        DataColumn(label: Text('السعر')),
        DataColumn(label: Text('الاستخدام')),
        DataColumn(label: Text('تاريخ الانتهاء')),
        DataColumn(label: Text('')),
      ];

  static DataRow build(
    ItemModel item, {
    required ItemTypeModel? type,
    required ExpiryProvider expiry,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return DataRow(
      onSelectChanged: (_) => onEdit(),
      cells: <DataCell>[
        DataCell(Text(item.label, style: AppTextStyles.tableCell)),
        DataCell(Text(item.itemTypeName ?? '—',
            style: AppTextStyles.tableCell)),
        DataCell(_fieldSummary(item, type)),
        DataCell(Text(
          item.defaultCost == null
              ? '—'
              : CurrencyFormatter.format(item.defaultCost!),
          style: AppTextStyles.money,
          textDirection: TextDirection.ltr,
        )),
        DataCell(Text(
          item.defaultPrice == null
              ? '—'
              : CurrencyFormatter.format(item.defaultPrice!),
          style: AppTextStyles.money,
          textDirection: TextDirection.ltr,
        )),
        DataCell(_UsageChip(item: item)),
        DataCell(
          item.expiryDate == null
              ? Text('—', style: AppTextStyles.tableCell)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      AppDateUtils.formatDate(item.expiryDate!),
                      style: AppTextStyles.tableCell,
                      textDirection: TextDirection.ltr,
                    ),
                    const SizedBox(width: 8),
                    ExpiryBadge(
                      level: expiry.levelForItem(item),
                      daysRemaining: expiry.daysRemaining(item.expiryDate),
                    ),
                  ],
                ),
        ),
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

  static Widget _fieldSummary(ItemModel item, ItemTypeModel? type) {
    if (type == null || type.fields.isEmpty || item.fieldValues.isEmpty) {
      return Text('—', style: AppTextStyles.caption);
    }

    final Map<int, String> values =
        DynamicFieldUtils.toValueMap(item.fieldValues);

    final List<String> parts = <String>[];
    for (final ItemTypeFieldModel field in type.fields) {
      final String? raw = values[field.id];
      if (raw == null || raw.trim().isEmpty) continue;
      parts.add(
        '${field.fieldName}: '
        '${DynamicFieldUtils.display(field.fieldType, raw)}',
      );
    }

    if (parts.isEmpty) return Text('—', style: AppTextStyles.caption);

    return Tooltip(
      message: parts.join('\n'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Text(
          parts.join(' · '),
          style: AppTextStyles.caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// Reusable items never deplete; single-use items show available or used.
class _UsageChip extends StatelessWidget {
  const _UsageChip({required this.item});

  final ItemModel item;

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color color;
    late final Color background;

    if (item.isReusable) {
      label = 'قابل لإعادة الاستخدام';
      color = AppColors.primary;
      background = AppColors.surface;
    } else if (item.isAvailable) {
      label = 'متاح';
      color = AppColors.success;
      background = AppColors.successSurface;
    } else {
      label = 'مستخدم';
      color = AppColors.danger;
      background = AppColors.dangerSurface;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption
            .copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
