import 'package:flutter/material.dart';

import '../../../../model/item_type_field_model.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_text_styles.dart';

/// One field in a type's schema, with reorder handle and edit / delete.
class FieldRow extends StatelessWidget {
  const FieldRow({
    super.key,
    required this.field,
    required this.onEdit,
    required this.onDelete,
  });

  final ItemTypeFieldModel field;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static String typeLabel(FieldType type) {
    switch (type) {
      case FieldType.text:
        return 'نص';
      case FieldType.number:
        return 'رقم';
      case FieldType.date:
        return 'تاريخ';
      case FieldType.bool:
        return 'نعم / لا';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.drag_indicator,
              size: 18, color: AppColors.textDisabled),
          const SizedBox(width: 10),
          Expanded(
            child: Text(field.fieldName, style: AppTextStyles.body),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(typeLabel(field.fieldType),
                style: AppTextStyles.caption),
          ),
          if (field.isRequired) ...<Widget>[
            const SizedBox(width: 8),
            Text(
              'Required',
              style: AppTextStyles.caption.copyWith(color: AppColors.danger),
            ),
          ],
          IconButton(
            tooltip: 'تعديل',
            icon: const Icon(Icons.edit_outlined, size: 17),
            color: AppColors.primary,
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: 'حذف',
            icon: const Icon(Icons.delete_outline, size: 17),
            color: AppColors.danger,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
