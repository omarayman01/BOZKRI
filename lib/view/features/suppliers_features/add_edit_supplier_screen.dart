import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../model/supplier_model.dart';
import '../../../view_model/cubit/suppliers/suppliers_cubit.dart';
import '../../../view_model/cubit/suppliers/suppliers_state.dart';
import '../../../view_model/provider/suppliers_cache_provider.dart';
import '../../../view_model/utils/validators.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/primary_button.dart';

class AddEditSupplierScreen extends StatefulWidget {
  const AddEditSupplierScreen({super.key, this.supplier});

  final SupplierModel? supplier;

  @override
  State<AddEditSupplierScreen> createState() => _AddEditSupplierScreenState();
}

class _AddEditSupplierScreenState extends State<AddEditSupplierScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _notes;
  late bool _isActive;

  bool get _isEditing => widget.supplier != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.supplier?.name ?? '');
    _phone = TextEditingController(text: widget.supplier?.phone ?? '');
    _notes = TextEditingController(text: widget.supplier?.notes ?? '');
    _isActive = widget.supplier?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final SuppliersCubit cubit = context.read<SuppliersCubit>();
    final SuppliersCacheProvider cache = context.read<SuppliersCacheProvider>();

    final bool ok = _isEditing
        ? await cubit.updateSupplier(
            cache,
            widget.supplier!.copyWith(
              name: _name.text.trim(),
              phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
              notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
              isActive: _isActive,
            ),
          )
        : await cubit.addSupplier(
            cache,
            name: _name.text.trim(),
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            isActive: _isActive,
          );

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editSupplier : l10n.newSupplier),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.contentPadding),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      AppTextField(
                        label: l10n.name,
                        controller: _name,
                        autofocus: true,
                        validator: Validators.name,
                      ),
                      const SizedBox(height: 18),
                      AppTextField(
                        label: l10n.phone,
                        controller: _phone,
                        textDirection: TextDirection.ltr,
                        keyboardType: TextInputType.phone,
                        validator: Validators.phone,
                      ),
                      const SizedBox(height: 18),
                      AppTextField(
                        label: l10n.notes,
                        controller: _notes,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppColors.primary,
                        title: Text(l10n.active),
                        value: _isActive,
                        onChanged: (bool v) => setState(() => _isActive = v),
                      ),
                      const SizedBox(height: 18),
                      BlocBuilder<SuppliersCubit, SuppliersState>(
                        builder: (BuildContext context, SuppliersState state) {
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
