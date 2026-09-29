import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../model/item_type_model.dart';
import '../../../../view_model/cubit/item_types/item_types_cubit.dart';
import '../../../../view_model/cubit/item_types/item_types_state.dart';
import '../../../../view_model/provider/items_cache_provider.dart';
import '../../../../view_model/utils/item_category.dart';
import '../../../../view_model/utils/validators.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_constants.dart';
import '../../../constants/app_text_styles.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/primary_button.dart';
import 'field_schema_editor.dart';

/// Manage item types and their schemas. Both sides are pure data: no code
/// change is needed to introduce a new type or field.
class ItemTypesManager extends StatelessWidget {
  const ItemTypesManager({super.key});

  Future<void> _addType(BuildContext context) async {
    final String? name = await _promptName(context, title: 'صنف جديد');
    if (name == null || !context.mounted) return;
    await context
        .read<ItemTypesCubit>()
        .addType(context.read<ItemsCacheProvider>(), name);
  }

  Future<void> _renameType(BuildContext context, ItemTypeModel type) async {
    final String? name = await _promptName(
      context,
      title: 'إعادة تسمية الصنف',
      initial: type.name,
    );
    if (name == null || !context.mounted) return;
    await context
        .read<ItemTypesCubit>()
        .renameType(context.read<ItemsCacheProvider>(), type.id, name);
  }

  Future<void> _deleteType(BuildContext context, ItemTypeModel type) async {
    if (categoryOf(type) == ItemCategory.car) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('لا يمكن حذف صنف "سيارة" — هو الصنف الأساسي الذي '
            'يعتمد عليه نظام السيارات.'),
      ));
      return;
    }

    final bool ok = await ConfirmDialog.show(
      context,
      title: 'حذف "${type.name}"؟',
      message: 'سيتم حذف هذا الصنف وكل الحقول الخاصة به.',
      confirmLabel: 'حذف',
      isDestructive: true,
      warning: 'لا يمكن حذف صنف لا يزال مستخدماً في عناصر.',
    );
    if (!ok || !context.mounted) return;

    final ItemTypesCubit cubit = context.read<ItemTypesCubit>();
    final bool deleted =
        await cubit.deleteType(context.read<ItemsCacheProvider>(), type.id);

    if (!deleted && context.mounted) {
      final String? message = cubit.state.errorMessage;
      if (message != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
        cubit.clearError();
      }
    }
  }

  static Future<String?> _promptName(
    BuildContext context, {
    required String title,
    String? initial,
  }) {
    final TextEditingController controller =
        TextEditingController(text: initial ?? '');
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title, style: AppTextStyles.title),
        content: SizedBox(
          width: 360,
          child: Form(
            key: formKey,
            child: AppTextField(
              label: 'الاسم',
              controller: controller,
              autofocus: true,
              validator: Validators.name,
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          PrimaryButton(
            label: 'حفظ',
            icon: Icons.check,
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              Navigator.of(dialogContext).pop(controller.text.trim());
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return BlocBuilder<ItemTypesCubit, ItemTypesState>(
      builder: (BuildContext context, ItemTypesState state) {
        if (state.isLoading) {
          return const SizedBox(height: 220, child: LoadingWidget());
        }

        if (state.isFailure) {
          return SizedBox(
            height: 220,
            child: ErrorStateWidget(
              message: state.errorMessage ?? l10n.errorGeneric,
              onRetry: () => context
                  .read<ItemTypesCubit>()
                  .load(context.read<ItemsCacheProvider>()),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(l10n.itemTypes, style: AppTextStyles.title),
                const Spacer(),
                PrimaryButton(
                  label: l10n.newItemType,
                  icon: Icons.add,
                  onPressed: () => _addType(context),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (state.types.isEmpty)
              EmptyStateWidget(
                title: 'لا توجد أصناف بعد',
                message: 'أنشئ صنفاً مثل "تذكرة طيران" أو "إيجار شقة"، ثم أضف له الحقول.',
                icon: Icons.category_outlined,
                actionLabel: l10n.newItemType,
                onAction: () => _addType(context),
              )
            else
              SizedBox(
                height: 420,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      width: 260,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius:
                              BorderRadius.circular(AppConstants.cardRadius),
                          border: Border.all(color: AppColors.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ListView.builder(
                          itemCount: state.types.length,
                          itemBuilder: (BuildContext context, int index) {
                            final ItemTypeModel type = state.types[index];
                            final bool selected =
                                type.id == state.selectedTypeId;
                            return ListTile(
                              selected: selected,
                              selectedTileColor: AppColors.surface,
                              title: Text(type.name,
                                  style: AppTextStyles.body),
                              subtitle: Text(
                                '${type.fields.length} حقل',
                                style: AppTextStyles.caption,
                              ),
                              onTap: () => context
                                  .read<ItemTypesCubit>()
                                  .selectType(type.id),
                              trailing: PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 18),
                                itemBuilder: (BuildContext _) =>
                                    <PopupMenuEntry<String>>[
                                  const PopupMenuItem<String>(
                                    value: 'rename',
                                    child: Text('إعادة تسمية'),
                                  ),
                                  if (categoryOf(type) != ItemCategory.car)
                                    const PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Text('حذف'),
                                    ),
                                ],
                                onSelected: (String action) =>
                                    action == 'rename'
                                        ? _renameType(context, type)
                                        : _deleteType(context, type),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: state.selectedType == null
                          ? EmptyStateWidget(
                              title: 'اختر صنفاً',
                              message:
                                  'Choose a type on the left to edit its '
                                  'field schema.',
                              icon: Icons.tune,
                            )
                          : SingleChildScrollView(
                              child:
                                  FieldSchemaEditor(type: state.selectedType!),
                            ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
