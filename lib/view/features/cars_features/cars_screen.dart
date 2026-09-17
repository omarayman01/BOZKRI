import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../model/item_model.dart';
import '../../../model/item_type_field_model.dart';
import '../../../model/item_type_model.dart';
import '../../../view_model/cubit/items/items_cubit.dart';
import '../../../view_model/provider/expiry_provider.dart';
import '../../../view_model/provider/items_cache_provider.dart';
import '../../../view_model/utils/item_category.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_text_styles.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/widgets/app_data_table.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/primary_button.dart';
import 'widgets/car_row.dart';

/// Every car in the system, regardless of which deals it has been used in —
/// a filtered view over the shared `items` table, scoped to whichever
/// admin-configured item type resolves to the car category.
class CarsScreen extends StatelessWidget {
  const CarsScreen({super.key});

  // Saving/deleting a car updates ItemsCacheProvider directly, so this
  // screen (which watches that cache) redraws with no reload step needed.
  Future<void> _openForm(BuildContext context, [ItemModel? car]) {
    return Navigator.of(context)
        .pushNamed(AppRoutes.addEditCar, arguments: car);
  }

  Future<void> _confirmDelete(BuildContext context, ItemModel car) async {
    final bool ok = await ConfirmDialog.show(
      context,
      title: 'حذف ${car.label}؟',
      message: 'سيتم حذف هذه السيارة نهائياً.',
      confirmLabel: 'حذف',
      isDestructive: true,
    );
    if (!ok || !context.mounted) return;

    await context.read<ItemsCubit>().deleteItem(
          context.read<ItemsCacheProvider>(),
          context.read<ExpiryProvider>(),
          car.id,
        );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ItemsCacheProvider cache = context.watch<ItemsCacheProvider>();

    final List<ItemTypeModel> carTypes = cache.types
        .where((ItemTypeModel t) => categoryOf(t) == ItemCategory.car)
        .toList();
    final Set<int> carTypeIds = carTypes.map((ItemTypeModel t) => t.id).toSet();
    final List<ItemTypeFieldModel> fields =
        carTypes.isEmpty ? const <ItemTypeFieldModel>[] : carTypes.first.fields;

    final List<ItemModel> cars = cache.items
        .where((ItemModel i) => carTypeIds.contains(i.itemTypeId))
        .toList();

    if (carTypes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppConstants.contentPadding),
        child: Center(
          child: Text(
            l10n.carsNoItemType,
            style: AppTextStyles.bodyMuted,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppConstants.contentPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Spacer(),
              PrimaryButton(
                label: l10n.newCar,
                icon: Icons.add,
                onPressed: () => _openForm(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: AppDataTable(
              emptyTitle: l10n.carsEmptyTitle,
              emptyMessage: l10n.carsEmptyMessage,
              emptyIcon: Icons.directions_car_outlined,
              emptyActionLabel: l10n.newCar,
              onEmptyAction: () => _openForm(context),
              columns: CarRow.columns(fields),
              rows: cars.map((ItemModel car) {
                return CarRow.build(
                  car,
                  fields: fields,
                  onEdit: () => _openForm(context, car),
                  onDelete: () => _confirmDelete(context, car),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
