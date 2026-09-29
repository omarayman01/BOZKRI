import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../model/item_model.dart';
import '../../../../model/supplier_model.dart';
import '../../../../model/transaction_model.dart';
import '../../../../view_model/database/local/daos/transactions_dao.dart';
import '../../../../view_model/provider/items_cache_provider.dart';
import '../../../../view_model/provider/suppliers_cache_provider.dart';
import '../../../../view_model/utils/currency_formatter.dart';
import '../../../../view_model/utils/validators.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_constants.dart';
import '../../../constants/app_text_styles.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/date_range_picker_field.dart';
import '../../../core/widgets/party_picker.dart';
import '../../cars_features/add_edit_car_screen.dart';
import 'item_availability_indicator.dart';

/// One editable line of the deal builder: supplier → item cascade, auto-filled
/// editable cost/price snapshots, quantity, optional expiry and rent dates.
class DealLineEditor extends StatefulWidget {
  const DealLineEditor({
    super.key,
    required this.index,
    required this.line,
    required this.dealType,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final DealLineInput line;
  final DealType dealType;
  final ValueChanged<DealLineInput> onChanged;
  final VoidCallback onRemove;

  @override
  State<DealLineEditor> createState() => _DealLineEditorState();
}

/// Default allowed kilometers per rental day for a car line; the admin can
/// still edit it freely per deal.
const double _defaultAllowedKmPerDay = 120;

class _DealLineEditorState extends State<DealLineEditor> {
  late final TextEditingController _qty;
  late final TextEditingController _cost;
  late final TextEditingController _price;
  late final TextEditingController _pricePerDay;
  late final TextEditingController _costPerDay;
  late final TextEditingController _days;
  late final TextEditingController _allowedKmPerDay;
  late final TextEditingController _pickupKilometer;

  @override
  void initState() {
    super.initState();
    _qty = TextEditingController(text: '${widget.line.qty}');
    _cost = TextEditingController(text: '${widget.line.unitCost}');
    _price = TextEditingController(text: '${widget.line.unitPrice}');
    _pricePerDay =
        TextEditingController(text: '${widget.line.pricePerDay ?? 0}');
    _costPerDay =
        TextEditingController(text: '${widget.line.costPerDay ?? 0}');
    _days = TextEditingController(text: '${widget.line.days ?? 1}');
    _allowedKmPerDay = TextEditingController(
        text: '${widget.line.allowedKmPerDay ?? _defaultAllowedKmPerDay}');
    _pickupKilometer =
        TextEditingController(text: '${widget.line.pickupKilometer ?? 0}');
  }

  @override
  void dispose() {
    _qty.dispose();
    _cost.dispose();
    _price.dispose();
    _pricePerDay.dispose();
    _costPerDay.dispose();
    _days.dispose();
    _allowedKmPerDay.dispose();
    _pickupKilometer.dispose();
    super.dispose();
  }

  int? _computedDays() {
    final DateTime? start = widget.line.rentStart;
    final DateTime? end = widget.line.rentEnd;
    if (start == null || end == null || end.isBefore(start)) return null;
    return DealLineInput.inclusiveDays(start, end);
  }

  void _togglePerDay(bool enabled) {
    if (!enabled) {
      widget.onChanged(widget.line.copyWith(clearPerDay: true));
      return;
    }
    final double price = widget.line.unitPrice;
    final double cost = widget.line.unitCost;
    final int days = _computedDays() ?? (widget.line.qty > 0 ? widget.line.qty : 1);
    final double allowedKmPerDay =
        widget.line.allowedKmPerDay ?? _defaultAllowedKmPerDay;
    _pricePerDay.text = '$price';
    _costPerDay.text = '$cost';
    _days.text = '$days';
    _allowedKmPerDay.text = '$allowedKmPerDay';
    widget.onChanged(widget.line.copyWith(
      pricePerDay: price,
      costPerDay: cost,
      days: days,
      unitPrice: price,
      unitCost: cost,
      qty: days,
      allowedKmPerDay: allowedKmPerDay,
      clearExpiry: true,
    ));
  }

  void _setPricePerDay(double value) {
    widget.onChanged(
      widget.line.copyWith(pricePerDay: value, unitPrice: value),
    );
  }

  void _setCostPerDay(double value) {
    widget.onChanged(
      widget.line.copyWith(costPerDay: value, unitCost: value),
    );
  }

  void _setAllowedKmPerDay(double value) =>
      widget.onChanged(widget.line.copyWith(allowedKmPerDay: value));

  void _setPickupKilometer(double value) =>
      widget.onChanged(widget.line.copyWith(pickupKilometer: value));

  /// The three per-day fields — start datetime, days, end date — always stay
  /// mutually consistent: whichever one the admin just edited drives the
  /// other two, with no separate "override" state to track or reconcile.

  /// Editing المده باليوم recomputes تاريخ الانتهاء from the current start.
  void _setDaysManually(int value) {
    final int days = value < 1 ? 1 : value;
    final DateTime? start = widget.line.rentStart;
    final DateTime? newEnd =
        start == null ? widget.line.rentEnd : start.add(Duration(days: days - 1));
    widget.onChanged(widget.line.copyWith(days: days, qty: days, rentEnd: newEnd));
  }

  /// Editing تاريخ البدء (date or time) keeps the current day count and
  /// shifts تاريخ الانتهاء to match.
  void _onRentStartChanged(DateTime? newStart) {
    if (newStart == null) {
      widget.onChanged(widget.line.copyWith(clearRent: true));
      return;
    }
    if (!widget.line.isPerDay) {
      widget.onChanged(widget.line.copyWith(rentStart: newStart));
      return;
    }
    final int days = widget.line.days ?? (widget.line.qty > 0 ? widget.line.qty : 1);
    final DateTime newEnd = newStart.add(Duration(days: days - 1));
    widget.onChanged(widget.line.copyWith(
      rentStart: newStart,
      rentEnd: newEnd,
      days: days,
      qty: days,
    ));
  }

  /// Editing تاريخ الانتهاء recomputes المده باليوم from the current start.
  void _onRentEndChanged(DateTime? newEnd) {
    if (newEnd == null) {
      widget.onChanged(widget.line.copyWith(clearRent: true));
      return;
    }
    if (!widget.line.isPerDay) {
      widget.onChanged(widget.line.copyWith(rentEnd: newEnd));
      return;
    }
    final DateTime? start = widget.line.rentStart;
    if (start == null || newEnd.isBefore(start)) {
      widget.onChanged(widget.line.copyWith(rentEnd: newEnd));
      return;
    }
    final int days = DealLineInput.inclusiveDays(start, newEnd);
    _days.text = '$days';
    widget.onChanged(widget.line.copyWith(rentEnd: newEnd, days: days, qty: days));
  }

  /// Switching supplier clears the item, since items cascade from the
  /// supplier. Only reachable before an item is chosen — once an item is
  /// selected, this picker is disabled and the supplier is derived from the
  /// item instead (see [_onItemChanged]).
  void _onSupplierChanged(SupplierModel? supplier) {
    widget.onChanged(
      widget.line.copyWith(
        supplierId: supplier?.id ?? 0,
        supplierName: supplier?.name ?? '',
        itemId: 0,
        itemLabel: '',
        isSingleUse: false,
        unitCost: 0,
        unitPrice: 0,
        clearExpiry: true,
      ),
    );
    _cost.text = '0';
    _price.text = '0';
  }

  /// Selecting an item auto-fills the editable snapshots, the expiry date,
  /// and — always — the line's supplier from the item's own supplier. For a
  /// car with no real supplier this is the seeded "بوزكري (بدون مورد)"
  /// placeholder; either way the supplier field locks once an item is set,
  /// since the line's supplier is never independent of which item it is.
  void _onItemChanged(ItemModel? item) {
    if (item == null) return;
    widget.onChanged(
      widget.line.copyWith(
        itemId: item.id,
        itemLabel: item.label,
        supplierId: item.supplierId,
        supplierName: item.supplierName ?? '',
        isSingleUse: item.isSingleUse,
        unitCost: item.defaultCost ?? 0,
        unitPrice: item.defaultPrice ?? 0,
        // Per-day (car) lines never carry an expiry date — they have their
        // own rental period instead.
        expiryDate: widget.line.isPerDay ? null : item.expiryDate,
        clearExpiry: widget.line.isPerDay,
      ),
    );
    _cost.text = '${item.defaultCost ?? 0}';
    _price.text = '${item.defaultPrice ?? 0}';
  }

  /// A new item was just created inline (see the "+" button next to the item
  /// dropdown) — select it immediately, same as picking it from the list.
  void _onItemCreated(ItemModel item) => _onItemChanged(item);

  /// "+" next to the item dropdown when no supplier is chosen — opens the
  /// same Add Car form used from the Cars tab, with its supplier field
  /// optional, and selects the newly created car for this line on success.
  Future<void> _addCarInline(BuildContext context) async {
    final ItemModel? created = await Navigator.of(context).push<ItemModel>(
      MaterialPageRoute<ItemModel>(
        builder: (_) => const AddEditCarScreen(),
      ),
    );
    if (created != null) _onItemCreated(created);
  }

  @override
  Widget build(BuildContext context) {
    final SuppliersCacheProvider suppliersCache =
        context.watch<SuppliersCacheProvider>();
    final ItemsCacheProvider itemsCache = context.watch<ItemsCacheProvider>();

    final SupplierModel? supplier =
        suppliersCache.byId(widget.line.supplierId);
    final ItemModel? selectedItem = itemsCache.byId(widget.line.itemId);

    // The picker only offers selectable items — this is the first half of the
    // dual enforcement; the commit transaction re-checks availability.
    //
    // With no supplier chosen yet, the item dropdown surfaces every
    // available car (across every supplier, including supplier-less ones)
    // rather than staying empty — this is what lets the admin pick a car
    // directly without picking a supplier first. Once a supplier IS chosen
    // (the old flow, still used for apartments/flights/etc.), it narrows to
    // that supplier's own items as before.
    final List<ItemModel> items = supplier == null
        ? itemsCache.availableCars
        : itemsCache.availableForSupplier(supplier.id);

    // Keep an already-committed item visible when editing, even if consumed.
    final List<ItemModel> options = <ItemModel>[
      ...items,
      if (selectedItem != null &&
          !items.any((ItemModel i) => i.id == selectedItem.id))
        selectedItem,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('السطر ${widget.index + 1}', style: AppTextStyles.label),
              const SizedBox(width: 12),
              if (selectedItem != null)
                ItemAvailabilityIndicator.forItem(selectedItem),
              const Spacer(),
              IconButton(
                tooltip: 'حذف السطر',
                icon: const Icon(Icons.delete_outline, size: 18),
                color: AppColors.danger,
                onPressed: widget.onRemove,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                // Once an item is chosen, the supplier is derived from it
                // (see _onItemChanged) and shown read-only here — a plain
                // display, not the interactive picker, since Autocomplete's
                // own text field never refreshes from an external value
                // change (only from the user actually picking an option),
                // so it would otherwise keep showing stale/blank text after
                // a car auto-fills its supplier.
                child: widget.line.itemId == 0
                    ? SupplierPicker(
                        suppliers: suppliersCache.activeSuppliers,
                        selected: supplier,
                        onSelected: _onSupplierChanged,
                      )
                    : InputDecorator(
                        decoration: const InputDecoration(labelText: 'المورد'),
                        child: Text(
                          supplier?.name ?? '',
                          style: AppTextStyles.body,
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: widget.line.itemId == 0 ? null : widget.line.itemId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'العنصر',
                          helperText: options.isEmpty
                              ? (supplier == null
                                  ? 'لا توجد سيارات متاحة'
                                  : 'لا توجد عناصر متاحة لهذا المورد')
                              : null,
                        ),
                        items: options
                            .map((ItemModel i) => DropdownMenuItem<int>(
                                  value: i.id,
                                  child: Text(
                                    i.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                        onChanged: (int? id) {
                          for (final ItemModel option in options) {
                            if (option.id == id) {
                              _onItemChanged(option);
                              return;
                            }
                          }
                        },
                      ),
                    ),
                    if (supplier == null)
                      Padding(
                        padding: const EdgeInsets.only(right: 4, top: 4),
                        child: IconButton(
                          tooltip: 'سيارة جديدة',
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          color: AppColors.primary,
                          onPressed: () => _addCarInline(context),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!widget.line.isPerDay)
            Row(
              children: <Widget>[
                Expanded(
                  child: AppTextField.integer(
                    label: 'الكمية',
                    controller: _qty,
                    validator: Validators.quantity,
                    onChanged: (String raw) => widget.onChanged(
                      widget.line.copyWith(qty: int.tryParse(raw) ?? 1),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: AppTextField.money(
                    label: 'سعر الوحدة (التكلفة)',
                    controller: _cost,
                    validator: (String? v) =>
                        Validators.money(v, field: 'سعر الوحدة (التكلفة)'),
                    onChanged: (String raw) => widget.onChanged(
                      widget.line.copyWith(
                          unitCost: CurrencyFormatter.parse(raw) ?? 0),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: AppTextField.money(
                    label: 'سعر الوحدة (البيع)',
                    controller: _price,
                    validator: (String? v) =>
                        Validators.money(v, field: 'سعر الوحدة (البيع)'),
                    onChanged: (String raw) => widget.onChanged(
                      widget.line.copyWith(
                          unitPrice: CurrencyFormatter.parse(raw) ?? 0),
                    ),
                  ),
                ),
              ],
            ),
          if (widget.dealType == DealType.rent) ...<Widget>[
            const SizedBox(height: 4),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: AppColors.primary,
              title: const Text('تسعير باليوم (مثل السيارات)'),
              value: widget.line.isPerDay,
              onChanged: _togglePerDay,
            ),
            if (widget.line.isPerDay) ...<Widget>[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text('بيانات الإيجار', style: AppTextStyles.label),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: SingleDateTimeField(
                            label: 'تاريخ البدء',
                            value: widget.line.rentStart,
                            onChanged: _onRentStartChanged,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: SingleDateField(
                            label: 'تاريخ الانتهاء',
                            value: widget.line.rentEnd,
                            onChanged: _onRentEndChanged,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: AppTextField.integer(
                            label: 'المده باليوم',
                            controller: _days,
                            validator: Validators.quantity,
                            onChanged: (String raw) =>
                                _setDaysManually(int.tryParse(raw) ?? 1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: AppTextField.money(
                            label: 'الكيلومتر الابتدائي',
                            controller: _pickupKilometer,
                            enabled: !widget.line.isReturned,
                            onChanged: (String raw) => _setPickupKilometer(
                                CurrencyFormatter.parse(raw) ?? 0),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: AppTextField.money(
                            label: 'السعر اليوم',
                            controller: _pricePerDay,
                            validator: (String? v) =>
                                Validators.money(v, field: 'السعر اليوم'),
                            onChanged: (String raw) => _setPricePerDay(
                                CurrencyFormatter.parse(raw) ?? 0),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: AppTextField.money(
                            label: 'سعر المعرض',
                            controller: _costPerDay,
                            validator: (String? v) =>
                                Validators.money(v, field: 'سعر المعرض'),
                            onChanged: (String raw) => _setCostPerDay(
                                CurrencyFormatter.parse(raw) ?? 0),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      label: 'الكيلومترات المسموحة باليوم',
                      controller: _allowedKmPerDay,
                      enabled: !widget.line.isReturned,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      textDirection: TextDirection.ltr,
                      suffix: const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Text('كم', style: AppTextStyles.caption),
                      ),
                      onChanged: (String raw) => _setAllowedKmPerDay(
                          CurrencyFormatter.parse(raw) ?? 0),
                    ),
                    if (widget.line.isReturned) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        'مغلق · الكيلومتر المستلم '
                        '${widget.line.returnKilometer ?? 0} · رسوم الكيلومتر الإضافي '
                        '${CurrencyFormatter.format(widget.line.extraKmCharge ?? 0)}',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.warning),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
          if (!widget.line.isPerDay) ...<Widget>[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: SingleDateField(
                    label: 'تاريخ الانتهاء (اختياري)',
                    value: widget.line.expiryDate,
                    onChanged: (DateTime? v) => widget.onChanged(
                      v == null
                          ? widget.line.copyWith(clearExpiry: true)
                          : widget.line.copyWith(expiryDate: v),
                    ),
                  ),
                ),
                if (widget.dealType == DealType.rent) ...<Widget>[
                  const SizedBox(width: 14),
                  Expanded(
                    child: SingleDateField(
                      label: 'تاريخ البدء',
                      value: widget.line.rentStart,
                      onChanged: _onRentStartChanged,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: SingleDateField(
                      label: 'تاريخ الانتهاء',
                      value: widget.line.rentEnd,
                      onChanged: _onRentEndChanged,
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Text(
              'الإجمالي ${CurrencyFormatter.format(widget.line.lineTotal)}'
              '  ·  الربح '
              '${CurrencyFormatter.signed(widget.line.lineProfit)}',
              style: AppTextStyles.money.copyWith(
                color: widget.line.lineProfit >= 0
                    ? AppColors.success
                    : AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
