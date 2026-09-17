import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../model/item_model.dart';
import '../../../../view_model/provider/expiry_provider.dart';
import '../../../../view_model/provider/items_cache_provider.dart';
import '../../../core/widgets/app_data_table.dart';
import 'item_row.dart';

/// Items supplied by this supplier. Item management lives here, not in a
/// top-level tab.
class SupplierItemsTab extends StatelessWidget {
  const SupplierItemsTab({
    super.key,
    required this.items,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final List<ItemModel> items;
  final VoidCallback onAdd;
  final ValueChanged<ItemModel> onEdit;
  final ValueChanged<ItemModel> onDelete;

  @override
  Widget build(BuildContext context) {
    final ExpiryProvider expiry = context.watch<ExpiryProvider>();
    final ItemsCacheProvider cache = context.watch<ItemsCacheProvider>();

    return AppDataTable(
      columns: ItemRow.columns(),
      emptyTitle: 'No items yet',
      emptyMessage: 'Add an item this supplier provides.',
      emptyIcon: Icons.inventory_2_outlined,
      emptyActionLabel: 'New item',
      onEmptyAction: onAdd,
      minWidth: 900,
      rows: items
          .map((ItemModel item) => ItemRow.build(
                item,
                type: cache.typeById(item.itemTypeId),
                expiry: expiry,
                onEdit: () => onEdit(item),
                onDelete: () => onDelete(item),
              ))
          .toList(),
    );
  }
}
