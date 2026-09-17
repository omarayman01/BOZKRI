import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../model/category_model.dart';
import '../../../model/expense_model.dart';
import '../../../view_model/cubit/expenses/expenses_cubit.dart';
import '../../../view_model/cubit/expenses/expenses_state.dart';
import '../../../view_model/utils/currency_formatter.dart';
import '../../../view_model/utils/validators.dart';
import '../../constants/app_text_styles.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/date_range_picker_field.dart';
import '../../core/widgets/primary_button.dart';

/// Add/edit dialog for one expense — title, category, amount, date, notes.
class AddEditExpenseDialog extends StatefulWidget {
  const AddEditExpenseDialog({super.key, this.expense});

  final ExpenseModel? expense;

  @override
  State<AddEditExpenseDialog> createState() => _AddEditExpenseDialogState();
}

class _AddEditExpenseDialogState extends State<AddEditExpenseDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late DateTime _date;
  int? _categoryId;

  bool get _isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.expense?.title ?? '');
    _amount = TextEditingController(
        text: widget.expense == null ? '' : '${widget.expense!.amount}');
    _note = TextEditingController(text: widget.expense?.note ?? '');
    _date = widget.expense?.dateTime ?? DateTime.now();
    _categoryId = widget.expense?.categoryId;
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final ExpensesCubit cubit = context.read<ExpensesCubit>();
    final double amount = CurrencyFormatter.parse(_amount.text) ?? 0;

    final bool ok = _isEditing
        ? await cubit.updateExpense(
            widget.expense!.copyWith(
              title: _title.text.trim(),
              amount: amount,
              categoryId: _categoryId,
              dateTime: _date,
              note: _note.text.trim().isEmpty ? null : _note.text.trim(),
            ),
          )
        : await cubit.addExpense(
            title: _title.text.trim(),
            amount: amount,
            categoryId: _categoryId,
            dateTime: _date,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
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
    final List<CategoryModel> categories =
        context.watch<ExpensesCubit>().state.categories;

    return AlertDialog(
      title: Text(_isEditing ? l10n.editExpense : l10n.newExpense,
          style: AppTextStyles.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppTextField(
                label: l10n.expenseTitle,
                controller: _title,
                autofocus: true,
                validator: (String? v) =>
                    Validators.notEmpty(v, field: 'Title'),
              ),
              const SizedBox(height: 16),
              AppTextField.money(
                label: l10n.amount,
                controller: _amount,
                validator: (String? v) =>
                    Validators.money(v, allowZero: false, field: 'Amount'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _categoryId,
                decoration: InputDecoration(labelText: l10n.expenseCategory),
                items: categories
                    .map((CategoryModel c) => DropdownMenuItem<int>(
                          value: c.id,
                          child: Text(c.name),
                        ))
                    .toList(),
                onChanged: (int? id) => setState(() => _categoryId = id),
              ),
              const SizedBox(height: 16),
              SingleDateField(
                label: l10n.date,
                value: _date,
                onChanged: (DateTime? v) =>
                    setState(() => _date = v ?? DateTime.now()),
              ),
              const SizedBox(height: 16),
              AppTextField(label: l10n.notes, controller: _note, maxLines: 2),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        BlocBuilder<ExpensesCubit, ExpensesState>(
          builder: (BuildContext context, ExpensesState state) {
            return PrimaryButton(
              label: l10n.save,
              icon: Icons.check,
              isLoading: state.isSaving,
              onPressed: _save,
            );
          },
        ),
      ],
    );
  }
}
