import 'package:flutter/material.dart';

import '../../../model/client_model.dart';
import '../../../model/supplier_model.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';

/// Searchable client selector backed by the shared clients cache.
class ClientPicker extends StatelessWidget {
  const ClientPicker({
    super.key,
    required this.clients,
    required this.selected,
    required this.onSelected,
    this.label = 'العميل',
    this.enabled = true,
  });

  final List<ClientModel> clients;
  final ClientModel? selected;
  final ValueChanged<ClientModel?> onSelected;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return _SearchablePicker<ClientModel>(
      label: label,
      enabled: enabled,
      options: clients,
      selected: selected,
      displayOf: (ClientModel c) => c.name,
      subtitleOf: (ClientModel c) => c.phone,
      matchOf: (ClientModel c) => <String>[
        c.name,
        c.phone ?? '',
        c.passportId ?? '',
        c.nationalId ?? '',
      ].join(' '),
      onSelected: onSelected,
      emptyHint: 'لا يوجد عملاء بعد — أضف عميلاً أولاً.',
      icon: Icons.person_outline,
    );
  }
}

/// Searchable supplier selector for deal lines.
class SupplierPicker extends StatelessWidget {
  const SupplierPicker({
    super.key,
    required this.suppliers,
    required this.selected,
    required this.onSelected,
    this.label = 'المورد',
    this.enabled = true,
  });

  final List<SupplierModel> suppliers;
  final SupplierModel? selected;
  final ValueChanged<SupplierModel?> onSelected;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return _SearchablePicker<SupplierModel>(
      label: label,
      enabled: enabled,
      options: suppliers,
      selected: selected,
      displayOf: (SupplierModel s) => s.name,
      subtitleOf: (SupplierModel s) => s.phone,
      onSelected: onSelected,
      emptyHint: 'لا يوجد موردون بعد — أضف مورداً أولاً.',
      icon: Icons.store_outlined,
    );
  }
}

class _SearchablePicker<T extends Object> extends StatelessWidget {
  const _SearchablePicker({
    required this.label,
    required this.options,
    required this.selected,
    required this.displayOf,
    required this.onSelected,
    required this.emptyHint,
    required this.icon,
    this.subtitleOf,
    this.matchOf,
    this.enabled = true,
  });

  final String label;
  final List<T> options;
  final T? selected;
  final String Function(T) displayOf;
  final String? Function(T)? subtitleOf;

  /// Extra text to search against, beyond [displayOf]. Defaults to
  /// [displayOf] when omitted.
  final String Function(T)? matchOf;
  final ValueChanged<T?> onSelected;
  final String emptyHint;
  final IconData icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return InputDecorator(
        decoration: InputDecoration(labelText: label, enabled: false),
        child: Text(emptyHint, style: AppTextStyles.bodyMuted),
      );
    }

    return Autocomplete<T>(
      // Flutter's Autocomplete only reads `initialValue` once, when it first
      // builds its own internal text controller — it never re-reads it on a
      // later rebuild. Without this key, selecting a value from OUTSIDE the
      // field itself (e.g. auto-filling the supplier from a chosen car, or
      // selecting a client just created via the "+" button) updates the
      // underlying data but leaves the field visually blank/stale. Keying
      // on the selected value forces Flutter to recreate the Autocomplete
      // (and its internal controller) whenever it changes externally.
      key: ValueKey<T?>(selected),
      initialValue: TextEditingValue(
        text: selected == null ? '' : displayOf(selected as T),
      ),
      displayStringForOption: displayOf,
      optionsBuilder: (TextEditingValue value) {
        final String query = value.text.trim().toLowerCase();
        if (query.isEmpty) return options;
        return options.where((T option) =>
            (matchOf ?? displayOf)(option).toLowerCase().contains(query));
      },
      onSelected: onSelected,
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController controller,
        FocusNode focusNode,
        VoidCallback onFieldSubmitted,
      ) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          style: AppTextStyles.body,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, size: 20, color: AppColors.secondary),
            suffixIcon: const Icon(Icons.expand_more,
                size: 20, color: AppColors.secondary),
          ),
        );
      },
      optionsViewBuilder: (
        BuildContext context,
        AutocompleteOnSelected<T> onAutocompleteSelected,
        Iterable<T> results,
      ) {
        return Align(
          alignment: AlignmentDirectional.topStart,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280, maxWidth: 420),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: results.length,
                itemBuilder: (BuildContext context, int index) {
                  final T option = results.elementAt(index);
                  final String? subtitle = subtitleOf?.call(option);
                  return ListTile(
                    dense: true,
                    title: Text(displayOf(option), style: AppTextStyles.body),
                    subtitle: subtitle == null || subtitle.isEmpty
                        ? null
                        : Text(subtitle, style: AppTextStyles.caption),
                    onTap: () => onAutocompleteSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
