import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../model/item_model.dart';
import '../../../model/item_type_field_model.dart';
import '../../../model/item_type_model.dart';
import '../../../model/supplier_model.dart';
import '../../../view_model/cubit/items/items_cubit.dart';
import '../../../view_model/cubit/items/items_state.dart';
import '../../../view_model/provider/expiry_provider.dart';
import '../../../view_model/provider/items_cache_provider.dart';
import '../../../view_model/provider/suppliers_cache_provider.dart';
import '../../../view_model/utils/currency_formatter.dart';
import '../../../view_model/utils/dynamic_field_utils.dart';
import '../../../view_model/utils/item_category.dart';
import '../../../view_model/utils/validators.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_text_styles.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/party_picker.dart';
import '../../core/widgets/primary_button.dart';
import '../suppliers_features/widgets/dynamic_fields_form.dart';

/// Add or edit a car directly, without going through a deal — the Car item
/// type's existing dynamic-field form plus a searchable supplier picker.
class AddEditCarScreen extends StatefulWidget {
  const AddEditCarScreen({super.key, this.car});

  final ItemModel? car;

  @override
  State<AddEditCarScreen> createState() => _AddEditCarScreenState();
}

class _AddEditCarScreenState extends State<AddEditCarScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final TextEditingController _cost;
  late final TextEditingController _price;
  late final TextEditingController _notes;

  int? _itemTypeId;
  int? _supplierId;
  bool _isActive = true;

  Map<int, String> _fieldValues = <int, String>{};
  Map<int, String> _fieldErrors = <int, String>{};

  bool get _isEditing => widget.car != null;

  @override
  void initState() {
    super.initState();
    final ItemModel? car = widget.car;
    _label = TextEditingController(text: car?.label ?? '');
    _cost = TextEditingController(
        text: car?.defaultCost == null ? '' : '${car!.defaultCost}');
    _price = TextEditingController(
        text: car?.defaultPrice == null ? '' : '${car!.defaultPrice}');
    _notes = TextEditingController(text: car?.notes ?? '');

    _itemTypeId = car?.itemTypeId;
    _supplierId = car?.supplierId;
    _isActive = car?.isActive ?? true;

    if (car != null) {
      _fieldValues = DynamicFieldUtils.toValueMap(car.fieldValues);
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

  List<ItemTypeModel> _carTypes(ItemsCacheProvider cache) => cache.types
      .where((ItemTypeModel t) => categoryOf(t) == ItemCategory.car)
      .toList();

  List<ItemTypeFieldModel> _schemaFor(ItemsCacheProvider cache) =>
      _itemTypeId == null
          ? const <ItemTypeFieldModel>[]
          : (cache.typeById(_itemTypeId!)?.fields ??
              const <ItemTypeFieldModel>[]);

  Future<void> _save() async {
    final ItemsCacheProvider cache = context.read<ItemsCacheProvider>();
    final List<ItemTypeFieldModel> schema = _schemaFor(cache);

    final bool staticOk = _formKey.currentState?.validate() ?? false;
    final Map<int, String> dynamicErrors =
        DynamicFieldUtils.validateAll(schema, _fieldValues);

    setState(() => _fieldErrors = dynamicErrors);

    if (!staticOk || dynamicErrors.isNotEmpty || _itemTypeId == null) {
      return;
    }

    final ItemsCubit cubit = context.read<ItemsCubit>();
    final ExpiryProvider expiry = context.read<ExpiryProvider>();
    final Map<int, String> pruned = DynamicFieldUtils.pruneEmpty(_fieldValues);

    // Leaving the supplier field empty assigns the car to the seeded
    // "بوزكري (بدون مورد)" placeholder rather than requiring a real one —
    // a car doesn't have to be rented from a supplier to exist in the fleet.
    final int? systemSupplierId =
        context.read<SuppliersCacheProvider>().systemSupplierId;
    final int effectiveSupplierId = _supplierId ?? systemSupplierId!;

    final ItemModel? created = _isEditing
        ? (await cubit.updateItem(
                  cache,
                  expiry,
                  id: widget.car!.id,
                  itemTypeId: _itemTypeId!,
                  supplierId: effectiveSupplierId,
                  label: _label.text,
                  defaultCost: CurrencyFormatter.parse(_cost.text),
                  defaultPrice: CurrencyFormatter.parse(_price.text),
                  isSingleUse: false,
                  isAvailable: true,
                  notes: _notes.text,
                  isActive: _isActive,
                  fieldValues: pruned,
                )
                ? widget.car
                : null)
        : await cubit.addItem(
            cache,
            expiry,
            itemTypeId: _itemTypeId!,
            supplierId: effectiveSupplierId,
            label: _label.text,
            defaultCost: CurrencyFormatter.parse(_cost.text),
            defaultPrice: CurrencyFormatter.parse(_price.text),
            isSingleUse: false,
            isAvailable: true,
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
    final ItemsCacheProvider itemsCache = context.watch<ItemsCacheProvider>();
    final SuppliersCacheProvider suppliersCache =
        context.watch<SuppliersCacheProvider>();
    final List<ItemTypeModel> carTypes = _carTypes(itemsCache);

    // Must run before _schemaFor below: with exactly one car type, no
    // dropdown ever exists to setState() this via onChanged, so the default
    // assignment has to land before the schema lookup in this same build —
    // otherwise the first (and only) build computes the schema while
    // _itemTypeId is still null, permanently freezing it empty.
    _itemTypeId ??= carTypes.isEmpty ? null : carTypes.first.id;

    final List<ItemTypeFieldModel> schema = _schemaFor(itemsCache);

    if (carTypes.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.newCar)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.contentPadding),
            child: Text(
              l10n.carsNoItemType,
              style: AppTextStyles.bodyMuted,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? l10n.editCar : l10n.newCar)),
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
                      if (carTypes.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: DropdownButtonFormField<int>(
                            value: _itemTypeId,
                            decoration:
                                InputDecoration(labelText: l10n.itemType),
                            items: carTypes
                                .map((ItemTypeModel t) => DropdownMenuItem<int>(
                                      value: t.id,
                                      child: Text(t.name),
                                    ))
                                .toList(),
                            onChanged: (int? id) => setState(() {
                              _itemTypeId = id;
                              _fieldErrors = <int, String>{};
                            }),
                          ),
                        ),
                      AppTextField(
                        label: l10n.itemLabel,
                        controller: _label,
                        validator: (String? v) =>
                            Validators.notEmpty(v, field: 'Label'),
                      ),
                      const SizedBox(height: 18),
                      SupplierPicker(
                        label: 'المورد (اختياري)',
                        suppliers: suppliersCache.activeSuppliers,
                        selected: _supplierId == null
                            ? null
                            : suppliersCache.byId(_supplierId!),
                        onSelected: (SupplierModel? s) =>
                            setState(() => _supplierId = s?.id),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'اتركه فارغاً إذا كانت السيارة غير تابعة لمورد.',
                          style: AppTextStyles.caption,
                        ),
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
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
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
