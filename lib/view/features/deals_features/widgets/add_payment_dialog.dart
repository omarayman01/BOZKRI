import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../../../model/payment_model.dart';
import '../../../../model/transaction_with_items_model.dart';
import '../../../../view_model/cubit/payments/payments_cubit.dart';
import '../../../../view_model/cubit/payments/payments_state.dart';
import '../../../../view_model/provider/suppliers_cache_provider.dart';
import '../../../../view_model/utils/currency_formatter.dart';
import '../../../../view_model/utils/validators.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_text_styles.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/date_range_picker_field.dart';
import '../../../core/widgets/primary_button.dart';

/// Records a client or supplier payment against one deal. Supplier payments
/// require a supplier so the money lands on the right payable.
class AddPaymentDialog extends StatefulWidget {
  const AddPaymentDialog({
    super.key,
    required this.deal,
    required this.party,
    this.supplierId,
  });

  final TransactionWithItemsModel deal;
  final PaymentParty party;

  /// Prefills the supplier when opened from a specific supplier's section.
  final int? supplierId;

  static Future<bool> show(
    BuildContext context, {
    required TransactionWithItemsModel deal,
    required PaymentParty party,
    int? supplierId,
  }) async {
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext _) => AddPaymentDialog(
        deal: deal,
        party: party,
        supplierId: supplierId,
      ),
    );
    return saved ?? false;
  }

  /// Display label for a payment method, shared with the deal detail screen.
  static String methodLabel(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'كاش';
      case PaymentMethod.mobileWallet:
        return 'محفظة';
      case PaymentMethod.instapay:
        return 'انستاباي';
    }
  }

  @override
  State<AddPaymentDialog> createState() => _AddPaymentDialogState();
}

class _AddPaymentDialogState extends State<AddPaymentDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _notes = TextEditingController();

  PaymentMethod _method = PaymentMethod.cash;
  DateTime _date = DateTime.now();
  int? _supplierId;

  bool get _isSupplier => widget.party == PaymentParty.supplier;

  @override
  void initState() {
    super.initState();
    _supplierId = widget.supplierId ??
        (widget.deal.supplierIds.length == 1
            ? widget.deal.supplierIds.first
            : null);
    _amount.text = _outstanding().toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// What is still owed on the selected side, used to prefill the amount.
  double _outstanding() {
    if (!_isSupplier) return widget.deal.clientOutstanding;
    if (_supplierId == null) return 0;
    return widget.deal.supplierOutstandingFor(_supplierId!);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isSupplier && _supplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر المورد الذي سيتم الدفع له.')),
      );
      return;
    }

    final PaymentsCubit cubit = context.read<PaymentsCubit>();
    final double amount = CurrencyFormatter.parse(_amount.text) ?? 0;

    final bool ok = _isSupplier
        ? await cubit.addSupplierPayment(
            transactionId: widget.deal.id,
            supplierId: _supplierId!,
            amount: amount,
            method: _method,
            dateTime: _date,
            notes: _notes.text,
          )
        : await cubit.addClientPayment(
            transactionId: widget.deal.id,
            amount: amount,
            method: _method,
            dateTime: _date,
            notes: _notes.text,
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
    final SuppliersCacheProvider suppliers =
        context.watch<SuppliersCacheProvider>();

    return AlertDialog(
      title: Text(
        _isSupplier ? 'دفعة مورد' : 'دفعة عميل',
        style: AppTextStyles.title,
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_isSupplier) ...<Widget>[
                DropdownButtonFormField<int>(
                  value: _supplierId,
                  decoration: const InputDecoration(labelText: 'المورد'),
                  items: widget.deal.supplierIds
                      .map((int id) => DropdownMenuItem<int>(
                            value: id,
                            child: Text(suppliers.nameOf(id)),
                          ))
                      .toList(),
                  onChanged: (int? id) => setState(() {
                    _supplierId = id;
                    _amount.text = _outstanding().toStringAsFixed(2);
                  }),
                ),
                const SizedBox(height: 8),
                Text(
                  'المتبقي لهذا المورد في هذه الصفقة: '
                  '${CurrencyFormatter.format(_outstanding())}',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 16),
              ] else ...<Widget>[
                Text(
                  'المتبقي: '
                  '${CurrencyFormatter.format(widget.deal.clientOutstanding)}',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 16),
              ],
              AppTextField.money(
                label: 'المبلغ',
                controller: _amount,
                validator: (String? v) =>
                    Validators.money(v, allowZero: false, field: 'المبلغ'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<PaymentMethod>(
                value: _method,
                decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                items: PaymentMethod.values
                    .map((PaymentMethod m) => DropdownMenuItem<PaymentMethod>(
                          value: m,
                          child: Text(AddPaymentDialog.methodLabel(m)),
                        ))
                    .toList(),
                onChanged: (PaymentMethod? m) =>
                    setState(() => _method = m ?? PaymentMethod.cash),
              ),
              const SizedBox(height: 16),
              SingleDateField(
                label: 'التاريخ',
                value: _date,
                onChanged: (DateTime? v) =>
                    setState(() => _date = v ?? DateTime.now()),
              ),
              const SizedBox(height: 16),
              AppTextField(label: 'ملاحظات', controller: _notes, maxLines: 2),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        BlocBuilder<PaymentsCubit, PaymentsState>(
          builder: (BuildContext context, PaymentsState state) {
            return PrimaryButton(
              label: 'تسجيل الدفعة',
              icon: Icons.check,
              isLoading: state.isSaving,
              onPressed: _save,
            );
          },
        ),
      ],
      backgroundColor: AppColors.white,
    );
  }
}
