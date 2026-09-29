import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../model/item_model.dart';
import '../../../model/item_type_field_model.dart';
import '../../../model/item_type_model.dart';
import '../../../view_model/cubit/items/items_cubit.dart';
import '../../../view_model/cubit/items/items_state.dart';
import '../../../view_model/provider/expiry_provider.dart';
import '../../../view_model/provider/items_cache_provider.dart';
import '../../../view_model/utils/currency_formatter.dart';
import '../../../view_model/utils/dynamic_field_utils.dart';
import '../../../view_model/utils/validators.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_text_styles.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/date_range_picker_field.dart';
import '../../core/widgets/primary_button.dart';
import 'widgets/dynamic_fields_form.dart';

/// Route arguments for the item form.
class AddEditItemArgs {
  const AddEditItemArgs({required this.supplierId, this.item});

  final int supplierId;
  final ItemModel? item;
}

/// Add or edit an item belonging to one supplier. The lower half of the form
/// is generated from the selected type's field schema.
class AddEditItemScreen extends StatefulWidget {
  const AddEditItemScreen({super.key, required this.supplierId, this.item});

  final int supplierId;
  final ItemModel? item;

  @override
  State<AddEditItemScreen> createState() => _AddEditItemScreenState();
}

class _AddEditItemScreenState extends State<AddEditItemScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final TextEditingController _cost;
  late final TextEditingController _price;
  late final TextEditingController _notes;

  int? _itemTypeId;
  DateTime? _expiryDate;
  bool _isSingleUse = false;
  bool _isAvailable = true;
  bool _isActive = true;

  Map<int, String> _fieldValues = <int, String>{};
  Map<int, String> _fieldErrors = <int, String>{};

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final ItemModel? item = widget.item;
    _label = TextEditingController(text: item?.label ?? '');
    _cost = TextEditingController(
        text: item?.defaultCost == null ? '' : '${item!.defaultCost}');
    _price = TextEditingController(
        text: item?.defaultPrice == null ? '' : '${item!.defaultPrice}');
    _notes = TextEditingController(text: item?.notes ?? '');

    _itemTypeId = item?.itemTypeId;
    _expiryDate = item?.expiryDate;
    _isSingleUse = item?.isSingleUse ?? false;
    _isAvailable = item?.isAvailable ?? true;
    _isActive = item?.isActive ?? true;

    if (item != null) {
      _fieldValues = DynamicFieldUtils.toValueMap(item.fieldValues);
    }
  }

  @override
  void dispose() {
    _label.dispose();
    _cost.dispose();
    _price.dispose();
    _notes.dispose();
    super.dispose();
  }

  List<ItemTypeFieldModel> _schemaFor(ItemsCacheProvider cache) =>
      _itemTypeId == null
          ? const <ItemTypeFieldModel>[]
          : (cache.typeById(_itemTypeId!)?.fields ??
              const <ItemTypeFieldModel>[]);

  Future<void> _save() async {
    final ItemsCacheProvider cache = context.read<ItemsCacheProvider>();
    final List<ItemTypeFieldModel> schema = _schemaFor(cache);

    // Both the static form fields and the dynamic schema must pass.
    final bool staticOk = _formKey.currentState?.validate() ?? false;
    final Map<int, String> dynamicErrors =
        DynamicFieldUtils.validateAll(schema, _fieldValues);

    setState(() => _fieldErrors = dynamicErrors);

    if (!staticOk || dynamicErrors.isNotEmpty || _itemTypeId == null) {
      if (_itemTypeId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose an item type first.')),
        );
      }
      return;
    }

    final ItemsCubit cubit = context.read<ItemsCubit>();
    final ExpiryProvider expiry = context.read<ExpiryProvider>();
    final Map<int, String> pruned = DynamicFieldUtils.pruneEmpty(_fieldValues);

    final ItemModel? created = _isEditing
        ? (await cubit.updateItem(
                  cache,
                  expiry,
                  id: widget.item!.id,
                  itemTypeId: _itemTypeId!,
                  supplierId: widget.supplierId,
                  label: _label.text,
                  defaultCost: CurrencyFormatter.parse(_cost.text),
                  defaultPrice: CurrencyFormatter.parse(_price.text),
                  expiryDate: _expiryDate,
                  isSingleUse: _isSingleUse,
                  isAvailable: _isSingleUse ? _isAvailable : true,
                  notes: _notes.text,
                  isActive: _isActive,
                  fieldValues: pruned,
                )
                ? widget.item
                : null)
        : await cubit.addItem(
            cache,
            expiry,
            itemTypeId: _itemTypeId!,
            supplierId: widget.supplierId,
            label: _label.text,
            defaultCost: CurrencyFormatter.parse(_cost.text),
            defaultPrice: CurrencyFormatter.parse(_price.text),
            expiryDate: _expiryDate,
            isSingleUse: _isSingleUse,
            isAvailable: _isSingleUse ? _isAvailable : true,
            notes: _notes.text,
            isActive: _isActive,
            fieldValues: pruned,
          );

    if (!mounted) return;
    if (created != null) {
      Navigator.of(context).pop(created);
    } else {
      final String? message = cubit.state.errorMessage;
      if (message != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
        cubit.clearError();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ItemsCacheProvider cache = context.watch<ItemsCacheProvider>();
    final List<ItemTypeModel> types = cache.types;
    final List<ItemTypeFieldModel> schema = _schemaFor(cache);

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? l10n.editItem : l10n.newItem)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.contentPadding),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      DropdownButtonFormField<int>(
                        value: _itemTypeId,
                        decoration: InputDecoration(labelText: l10n.itemType),
                        items: types
                            .map((ItemTypeModel t) => DropdownMenuItem<int>(
                                  value: t.id,
                                  child: Text(t.name),
                                ))
                            .toList(),
                        onChanged: (int? id) => setState(() {
                          _itemTypeId = id;
                          _fieldErrors = <int, String>{};
                        }),
                        validator: (int? v) =>
                            v == null ? 'Choose an item type.' : null,
                      ),
                      const SizedBox(height: 18),
                      AppTextField(
                        label: l10n.itemLabel,
                        controller: _label,
                        validator: (String? v) =>
                            Validators.notEmpty(v, field: 'Label'),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: AppTextField.money(
                              label: l10n.defaultCost,
                              controller: _cost,
                              validator: (String? v) => Validators.money(
                                v,
                                isRequired: false,
                                field: 'Cost',
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: AppTextField.money(
                              label: l10n.defaultPrice,
                              controller: _price,
                              validator: (String? v) => Validators.money(
                                v,
                                isRequired: false,
                                field: 'Price',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SingleDateField(
                        label: l10n.expiryDate,
                        value: _expiryDate,
                        onChanged: (DateTime? v) =>
                            setState(() => _expiryDate = v),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppColors.primary,
                        title: Text(l10n.singleUse),
                        subtitle: Text(
                          'A consumable one-time item. Reusable templates '
                          'never deplete.',
                          style: AppTextStyles.caption,
                        ),
                        value: _isSingleUse,
                        onChanged: (bool v) => setState(() {
                          _isSingleUse = v;
                          if (!v) _isAvailable = true;
                        }),
                      ),
                      if (_isSingleUse)
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppColors.primary,
                          title: Text(l10n.itemAvailable),
                          subtitle: Text(
                            'Turn off once this item has been consumed by a '
                            'deal.',
                            style: AppTextStyles.caption,
                          ),
                          value: _isAvailable,
                          onChanged: (bool v) =>
                              setState(() => _isAvailable = v),
                        ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppColors.primary,
                        title: Text(l10n.active),
                        value: _isActive,
                        onChanged: (bool v) => setState(() => _isActive = v),
                      ),
                      const SizedBox(height: 18),
                      AppTextField(
                        label: l10n.notes,
                        controller: _notes,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 26),
                      Text(l10n.fieldSchema, style: AppTextStyles.title),
                      const SizedBox(height: 14),
                      DynamicFieldsForm(
                        schema: schema,
                        values: _fieldValues,
                        errors: _fieldErrors,
                        onChanged: (int fieldId, String value) {
                          setState(() {
                            _fieldValues = <int, String>{
                              ..._fieldValues,
                              fieldId: value,
                            };
                            _fieldErrors = <int, String>{..._fieldErrors}
                              ..remove(fieldId);
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      BlocBuilder<ItemsCubit, ItemsState>(
                        builder: (BuildContext context, ItemsState state) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: <Widget>[
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(l10n.cancel),
                              ),
                              const SizedBox(width: 12),
                              PrimaryButton(
                                label: l10n.save,
                                icon: Icons.check,
                                isLoading: state.isSaving,
                                onPressed: _save,
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
