import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../model/client_model.dart';
import '../../../view_model/cubit/clients/clients_cubit.dart';
import '../../../view_model/cubit/clients/clients_state.dart';
import '../../../view_model/provider/clients_cache_provider.dart';
import '../../../view_model/utils/validators.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/primary_button.dart';

/// Comfortable-density form for creating or editing a client.
class AddEditClientScreen extends StatefulWidget {
  const AddEditClientScreen({super.key, this.client});

  final ClientModel? client;

  @override
  State<AddEditClientScreen> createState() => _AddEditClientScreenState();
}

class _AddEditClientScreenState extends State<AddEditClientScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _notes;
  late final TextEditingController _passportId;
  late final TextEditingController _nationalId;
  late bool _isActive;

  bool get _isEditing => widget.client != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.client?.name ?? '');
    _phone = TextEditingController(text: widget.client?.phone ?? '');
    _notes = TextEditingController(text: widget.client?.notes ?? '');
    _passportId = TextEditingController(text: widget.client?.passportId ?? '');
    _nationalId = TextEditingController(text: widget.client?.nationalId ?? '');
    _isActive = widget.client?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _notes.dispose();
    _passportId.dispose();
    _nationalId.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final ClientsCubit cubit = context.read<ClientsCubit>();
    final ClientsCacheProvider cache = context.read<ClientsCacheProvider>();

    final String? passportId =
        _passportId.text.trim().isEmpty ? null : _passportId.text.trim();
    final String? nationalId =
        _nationalId.text.trim().isEmpty ? null : _nationalId.text.trim();

    final bool ok = _isEditing
        ? await cubit.updateClient(
            cache,
            widget.client!.copyWith(
              name: _name.text.trim(),
              phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
              notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
              isActive: _isActive,
              passportId: passportId,
              nationalId: nationalId,
            ),
          )
        : await cubit.addClient(
            cache,
            name: _name.text.trim(),
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            isActive: _isActive,
            passportId: passportId,
            nationalId: nationalId,
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
        title: Text(_isEditing ? l10n.editClient : l10n.newClient),
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
                      const SizedBox(height: 18),
                      AppTextField(
                        label: l10n.passportId,
                        controller: _passportId,
                        textDirection: TextDirection.ltr,
                      ),
                      const SizedBox(height: 18),
                      AppTextField(
                        label: l10n.nationalId,
                        controller: _nationalId,
                        textDirection: TextDirection.ltr,
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
                      BlocBuilder<ClientsCubit, ClientsState>(
                        builder: (BuildContext context, ClientsState state) {
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
