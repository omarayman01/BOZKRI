import 'package:flutter/material.dart';

import '../../../../model/item_model.dart';
import '../../../../model/item_type_model.dart';
import '../../../../model/transaction_item_model.dart';
import '../../../../model/transaction_model.dart';
import '../../../../model/transaction_with_items_model.dart';
import '../../../../view_model/provider/items_cache_provider.dart';
import '../../../../view_model/utils/currency_formatter.dart';
import '../../../../view_model/utils/date_utils.dart';
import '../../../../view_model/utils/item_category.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_text_styles.dart';
import '../../../core/widgets/payment_status_chip.dart';

/// One row of the deals table: date, used item, client, suppliers, totals,
/// both payment statuses and the deal status. Leads with the item actually
/// used rather than the internal deal number/id.
class DealRow {
  const DealRow._();

  static List<DataColumn> columns() => const <DataColumn>[
        DataColumn(label: Text('التاريخ')),
        DataColumn(label: Text('العنصر')),
        DataColumn(label: Text('العميل')),
        DataColumn(label: Text('الموردون')),
        DataColumn(label: Text('الاجمالي')),
        DataColumn(label: Text('صافي الربح')),
        DataColumn(label: Text('دفعة العميل')),
        DataColumn(label: Text('دفعة المورد')),
        DataColumn(label: Text('الحالة')),
        DataColumn(label: Text('')),
      ];

  static DataRow build(
    TransactionWithItemsModel deal, {
    required ItemsCacheProvider itemsCache,
    required VoidCallback onOpen,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    final String suppliers = deal.supplierNames.isEmpty
        ? '—'
        : deal.supplierNames.join(', ');

    return DataRow(
      onSelectChanged: (_) => onOpen(),
      cells: <DataCell>[
        DataCell(Text(
          AppDateUtils.formatDate(deal.transaction.dateTime),
          style: AppTextStyles.tableCell,
          textDirection: TextDirection.ltr,
        )),
        DataCell(_usedItemCell(deal, itemsCache)),
        DataCell(Text(deal.transaction.clientName ?? '—',
            style: AppTextStyles.tableCell)),
        DataCell(ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Text(
            suppliers,
            style: AppTextStyles.tableCell,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        )),
        DataCell(Text(
          CurrencyFormatter.format(deal.netRevenue),
          style: AppTextStyles.money,
          textDirection: TextDirection.ltr,
        )),
        DataCell(Text(
          CurrencyFormatter.signed(deal.netProfit),
          style: AppTextStyles.profit(deal.netProfit),
          textDirection: TextDirection.ltr,
        )),
        DataCell(PaymentStatusChip(status: deal.displayedClientStatus, compact: true)),
        DataCell(PaymentStatusChip(status: deal.supplierStatus, compact: true)),
        DataCell(_statusCell(deal)),
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

  /// Refund status (مسترجع جزئياً/بالكامل) takes priority when it applies;
  /// otherwise, for a deal made up of car/per-day lines, the line-level
  /// حالة العقد (ساري/مغلق) is shown here too, so closing a line from the
  /// detail screen is reflected in this list without re-navigating.
  static Widget _statusCell(TransactionWithItemsModel deal) {
    if (deal.transaction.status != TransactionStatus.active) {
      return DealStatusChip(status: deal.transaction.status, compact: true);
    }
    if (deal.hasPerDayLines) {
      return LineStatusChip(closed: deal.allPerDayLinesClosed, compact: true);
    }
    return DealStatusChip(status: deal.transaction.status, compact: true);
  }

  /// The primary line's used item — a car's make/model + plate when those
  /// dynamic fields are available, otherwise the plain item label — plus a
  /// trailing "+N" badge for any additional lines.
  static Widget _usedItemCell(
    TransactionWithItemsModel deal,
    ItemsCacheProvider itemsCache,
  ) {
    final TransactionItemModel primary = deal.primaryItem;
    final String label = _itemDisplayLabel(primary, itemsCache);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Text(
            label,
            style: AppTextStyles.tableCell,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (deal.additionalItemCount > 0) ...<Widget>[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              '+${deal.additionalItemCount}',
              style: AppTextStyles.caption,
              textDirection: TextDirection.ltr,
            ),
          ),
        ],
      ],
    );
  }

  static String _itemDisplayLabel(
    TransactionItemModel line,
    ItemsCacheProvider itemsCache,
  ) {
    final ItemModel? item = itemsCache.byId(line.itemId);
    final String label = line.itemLabel ?? item?.label ?? '—';
    if (item == null) return label;

    final ItemTypeModel? type = itemsCache.typeById(item.itemTypeId);
    if (type == null || categoryOf(type) != ItemCategory.car) return label;

    final String plate = pickFieldValue(
      fieldValuesByName(item, type),
      <String>['رقم اللوحة', 'لوحة', 'plate'],
    );
    return plate.isEmpty ? label : '$label ($plate)';
  }
}
