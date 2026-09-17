import 'package:flutter/material.dart';

import '../../../model/item_type_field_model.dart';
import '../../../view_model/utils/dynamic_field_utils.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import 'app_text_field.dart';
import 'date_range_picker_field.dart';

/// Renders a single dynamic field's input, chosen purely from the schema's
/// [FieldType]. Nothing here is hard-coded per item type, so a new field added
/// in Settings appears in the form immediately.
class DynamicFieldInput extends StatelessWidget {
  const DynamicFieldInput({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
    this.errorText,
    this.enabled = true,
  });

  final ItemTypeFieldModel field;

  /// Raw stored representation of the value.
  final String value;
  final ValueChanged<String> onChanged;
  final String? errorText;
  final bool enabled;

  String get _label =>
      field.isRequired ? '${field.fieldName} *' : field.fieldName;

  @override
  Widget build(BuildContext context) {
    switch (field.fieldType) {
      case FieldType.text:
        return AppTextField(
          label: _label,
          initialValue: value,
          enabled: enabled,
          onChanged: (String raw) =>
              onChanged(DynamicFieldUtils.encode(FieldType.text, raw)),
          validator: (String? _) => errorText,
        );

      case FieldType.number:
        return AppTextField(
          label: _label,
          initialValue: value,
          enabled: enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textDirection: TextDirection.ltr,
          onChanged: (String raw) =>
              onChanged(DynamicFieldUtils.encode(FieldType.number, raw)),
          validator: (String? _) => errorText,
        );

      case FieldType.date:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SingleDateField(
              label: _label,
              enabled: enabled,
              value: DynamicFieldUtils.decodeDate(value),
              onChanged: (DateTime? picked) =>
                  onChanged(DynamicFieldUtils.encode(FieldType.date, picked)),
            ),
            if (errorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 12),
                child: Text(
                  errorText!,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.danger),
                ),
              ),
          ],
        );

      case FieldType.bool:
        return SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(field.fieldName, style: AppTextStyles.body),
          value: DynamicFieldUtils.decodeBool(value),
          activeColor: AppColors.primary,
          onChanged: enabled
              ? (bool next) =>
                  onChanged(DynamicFieldUtils.encode(FieldType.bool, next))
              : null,
        );
    }
  }
}
