import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../model/item_type_field_model.dart';
import '../../../../model/item_type_model.dart';
import '../../../../view_model/cubit/item_types/item_types_cubit.dart';
import '../../../../view_model/provider/items_cache_provider.dart';
import '../../../../view_model/utils/validators.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_text_styles.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/primary_button.dart';
import 'field_row.dart';

/// Edits one item type's field schema. Everything here is data — the item form
/// picks the changes up with no code edits.
class FieldSchemaEditor extends StatelessWidget {
  const FieldSchemaEditor({super.key, required this.type});

  final ItemTypeModel type;

  Future<void> _addOrEdit(BuildContext context,
      [ItemTypeFieldModel? field]) async {
    final ItemTypesCubit cubit = context.read<ItemTypesCubit>();
    final ItemsCacheProvider cache = context.read<ItemsCacheProvider>();

    final _FieldDraft? draft = await showDialog<_FieldDraft>(
      context: context,
      builder: (BuildContext _) => _FieldDialog(field: field),
    );
    if (draft == null) return;

    if (field == null) {
      await cubit.addField(
        cache,
        itemTypeId: type.id,
        fieldName: draft.name,
        fieldType: draft.type,
        isRequired: draft.isRequired,
      );
    } else {
      await cubit.updateField(
        cache,
        field.copyWith(
          fieldName: draft.name,
          fieldType: draft.type,
          isRequired: draft.isRequired,
        ),
      );
    }
  }

  Future<void> _delete(
      BuildContext context, ItemTypeFieldModel field) async {
    final bool ok = await ConfirmDialog.show(
      context,
      title: 'حذف "${field.fieldName}"؟',
      message: 'سيتم حذف هذا الحقل وكل القيم المحفوظة فيه.',
      confirmLabel: 'حذف',
      isDestructive: true,
      warning: 'القيم المحفوظة مسبقاً على العناصر لهذا الحقل سيتم حذفها أيضاً.',
    );
    if (!ok || !context.mounted) return;

    await context.read<ItemTypesCubit>().deleteField(
          context.read<ItemsCacheProvider>(),
          field.id,
        );
  }

  Future<void> _reorder(BuildContext context, int oldIndex, int newIndex) async {
    final List<ItemTypeFieldModel> fields =
        List<ItemTypeFieldModel>.from(type.fields);
    final int target = newIndex > oldIndex ? newIndex - 1 : newIndex;
    final ItemTypeFieldModel moved = fields.removeAt(oldIndex);
    fields.insert(target, moved);

    await context.read<ItemTypesCubit>().reorderFields(
          context.read<ItemsCacheProvider>(),
          fields.map((ItemTypeFieldModel f) => f.id).toList(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text('${l10n.fieldSchema} — ${type.name}',
                style: AppTextStyles.title),
            const Spacer(),
            PrimaryButton(
              label: l10n.newField,
              icon: Icons.add,
              onPressed: () => _addOrEdit(context),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (type.fields.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              'No fields yet. Add one and it appears on every item of this '
              'type immediately.',
              style: AppTextStyles.bodyMuted,
            ),
          )
        else
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: true,
            onReorder: (int oldIndex, int newIndex) =>
                _reorder(context, oldIndex, newIndex),
            children: <Widget>[
              for (final ItemTypeFieldModel field in type.fields)
                Padding(
                  key: ValueKey<int>(field.id),
                  padding: EdgeInsets.zero,
                  child: FieldRow(
                    field: field,
                    onEdit: () => _addOrEdit(context, field),
                    onDelete: () => _delete(context, field),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _FieldDraft {
  const _FieldDraft({
    required this.name,
    required this.type,
    required this.isRequired,
  });

  final String name;
  final FieldType type;
  final bool isRequired;
}

class _FieldDialog extends StatefulWidget {
  const _FieldDialog({this.field});

  final ItemTypeFieldModel? field;

  @override
  State<_FieldDialog> createState() => _FieldDialogState();
}

class _FieldDialogState extends State<_FieldDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late FieldType _type;
  late bool _isRequired;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.field?.fieldName ?? '');
    _type = widget.field?.fieldType ?? FieldType.text;
    _isRequired = widget.field?.isRequired ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(widget.field == null ? l10n.newField : l10n.edit,
          style: AppTextStyles.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppTextField(
                label: l10n.fieldName,
                controller: _name,
                autofocus: true,
                validator: (String? v) =>
                    Validators.notEmpty(v, field: 'Field name'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<FieldType>(
                value: _type,
                decoration: InputDecoration(labelText: l10n.fieldType),
                items: FieldType.values
                    .map((FieldType t) => DropdownMenuItem<FieldType>(
                          value: t,
                          child: Text(FieldRow.typeLabel(t)),
                        ))
                    .toList(),
                onChanged: (FieldType? t) =>
                    setState(() => _type = t ?? FieldType.text),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.primary,
                title: Text(l10n.fieldRequired),
                value: _isRequired,
                onChanged: (bool v) => setState(() => _isRequired = v),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        PrimaryButton(
          label: l10n.save,
          icon: Icons.check,
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.of(context).pop(_FieldDraft(
              name: _name.text.trim(),
              type: _type,
              isRequired: _isRequired,
            ));
          },
        ),
      ],
    );
  }
}
