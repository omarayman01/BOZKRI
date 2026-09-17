import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_text_styles.dart';

/// Labelled text field used across every form. Numeric and money variants pin
/// the input to Western digits so figures stay LTR even in the Arabic UI.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.initialValue,
    this.hint,
    this.helper,
    this.validator,
    this.onChanged,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.enabled = true,
    this.autofocus = false,
    this.prefixIcon,
    this.suffix,
    this.textDirection,
  });

  /// Money field: decimal keypad, LTR digits, EGP suffix.
  factory AppTextField.money({
    Key? key,
    required String label,
    TextEditingController? controller,
    String? initialValue,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    bool enabled = true,
    String? helper,
  }) {
    return AppTextField(
      key: key,
      label: label,
      controller: controller,
      initialValue: initialValue,
      helper: helper,
      validator: validator,
      onChanged: onChanged,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      textDirection: TextDirection.ltr,
      suffix: const Padding(
        padding: EdgeInsets.only(right: 4),
        child: Text(AppConstants.currencySymbol, style: AppTextStyles.caption),
      ),
    );
  }

  /// Whole-number field.
  factory AppTextField.integer({
    Key? key,
    required String label,
    TextEditingController? controller,
    String? initialValue,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    bool enabled = true,
  }) {
    return AppTextField(
      key: key,
      label: label,
      controller: controller,
      initialValue: initialValue,
      validator: validator,
      onChanged: onChanged,
      enabled: enabled,
      keyboardType: TextInputType.number,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
      ],
      textDirection: TextDirection.ltr,
    );
  }

  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final String? hint;
  final String? helper;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final bool enabled;
  final bool autofocus;
  final IconData? prefixIcon;
  final Widget? suffix;
  final TextDirection? textDirection;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      validator: validator,
      onChanged: onChanged,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      enabled: enabled,
      autofocus: autofocus,
      textDirection: textDirection,
      style: AppTextStyles.body,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, size: 20, color: AppColors.secondary),
        suffixIcon: suffix,
      ),
    );
  }
}
