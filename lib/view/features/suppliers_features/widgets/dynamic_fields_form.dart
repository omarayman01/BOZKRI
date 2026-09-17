import 'package:flutter/material.dart';

import '../../../../model/item_type_field_model.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_text_styles.dart';
import '../../../core/widgets/dynamic_field_input.dart';

/// Renders an entire item type's field schema as a form. Purely data-driven:
/// no code change is needed when a type or field is added in Settings.
class DynamicFieldsForm extends StatelessWidget {
  const DynamicFieldsForm({
    super.key,
    required this.schema,
    required this.values,
    required this.onChanged,
    this.errors = const <int, String>{},
    this.enabled = true,
  });

  final List<ItemTypeFieldModel> schema;

  /// fieldId -> raw stored value.
  final Map<int, String> values;

  /// Called with (fieldId, newRawValue).
  final void Function(int fieldId, String value) onChanged;

  /// fieldId -> validation message.
  final Map<int, String> errors;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (schema.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.info_outline,
                size: 18, color: AppColors.secondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'This type has no custom fields. Add some in Settings → Item '
                'types.',
                style: AppTextStyles.caption,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final ItemTypeFieldModel field in schema)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: DynamicFieldInput(
              key: ValueKey<int>(field.id),
              field: field,
              value: values[field.id] ?? '',
              errorText: errors[field.id],
              enabled: enabled,
              onChanged: (String raw) => onChanged(field.id, raw),
            ),
          ),
      ],
    );
  }
}
