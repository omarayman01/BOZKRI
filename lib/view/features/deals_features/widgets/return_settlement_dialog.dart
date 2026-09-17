import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../model/transaction_item_model.dart';
import '../../../../view_model/cubit/deals/deals_cubit.dart';
import '../../../../view_model/cubit/deals/deals_state.dart';
import '../../../../view_model/utils/currency_formatter.dart';
import '../../../../view_model/utils/return_settlement_calculator.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_text_styles.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';

/// Closes one per-day (car) line. When the line has an allowance
/// (`allowedKmPerDay` set), the admin enters the received kilometer and the
/// extra-km rate here — at close time, not creation — and sees the full km
/// breakdown live; otherwise only the received kilometer is asked for and a
/// plain "no extra charge" message is shown. `closeCarLine` runs as a single
/// Drift transaction; the line can later be re-opened.
class ReturnSettlementDialog extends StatefulWidget {
  const ReturnSettlementDialog({
    super.key,
    required this.transactionId,
    required this.line,
    required this.alreadyPaid,
  });

  final int transactionId;
  final TransactionItemModel line;

  /// Payments already recorded on this line, so the preview can show what
  /// will still be owed after closing.
  final double alreadyPaid;

  static Future<bool> show(
    BuildContext context, {
    required int transactionId,
    required TransactionItemModel line,
    required double alreadyPaid,
  }) async {
    final bool? done = await showDialog<bool>(
      context: context,
      builder: (BuildContext _) => ReturnSettlementDialog(
        transactionId: transactionId,
        line: line,
        alreadyPaid: alreadyPaid,
      ),
    );
    return done ?? false;
  }

  @override
  State<ReturnSettlementDialog> createState() =>
      _ReturnSettlementDialogState();
}

class _ReturnSettlementDialogState extends State<ReturnSettlementDialog> {
  late final TextEditingController _returnKm;
  late final TextEditingController _extraKmRate;

  bool get _hasAllowance => widget.line.allowedKmPerDay != null;

  @override
  void initState() {
    super.initState();
    _returnKm = TextEditingController(
      text: '${widget.line.pickupKilometer ?? 0}',
    );
    _extraKmRate = TextEditingController();
  }

  @override
  void dispose() {
    _returnKm.dispose();
    _extraKmRate.dispose();
    super.dispose();
  }

  ReturnSettlementResult? _preview() {
    if (!_hasAllowance) return null;
    final TransactionItemModel line = widget.line;
    final double? returnKm = CurrencyFormatter.parse(_returnKm.text);
    final double? rate = CurrencyFormatter.parse(_extraKmRate.text);
    if (returnKm == null ||
        rate == null ||
        line.pickupKilometer == null ||
        line.pricePerDay == null ||
        line.days == null) {
      return null;
    }
    return ReturnSettlementCalculator.compute(
      pickupKilometer: line.pickupKilometer!,
      returnKilometer: returnKm,
      allowedKmPerDay: line.allowedKmPerDay!,
      days: line.days!,
      extraKmRate: rate,
      pricePerDay: line.pricePerDay!,
      alreadyPaid: widget.alreadyPaid,
    );
  }

  bool get _canConfirm {
    final double? returnKm = CurrencyFormatter.parse(_returnKm.text);
    if (returnKm == null) return false;
    if (!_hasAllowance) return true;
    return _preview() != null;
  }

  Future<void> _confirm() async {
    final DealsCubit cubit = context.read<DealsCubit>();
    final bool ok = await cubit.closeCarLine(
      transactionId: widget.transactionId,
      transactionItemId: widget.line.id,
      returnKilometer: CurrencyFormatter.parse(_returnKm.text) ?? 0,
      extraKmRate:
          _hasAllowance ? CurrencyFormatter.parse(_extraKmRate.text) : null,
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
    final ReturnSettlementResult? preview = _preview();

    return AlertDialog(
      title: const Text('إغلاق السطر', style: AppTextStyles.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppTextField.money(
              label: 'الكيلومتر المستلم',
              controller: _returnKm,
              onChanged: (_) => setState(() {}),
            ),
            if (!_hasAllowance) ...<Widget>[
              const SizedBox(height: 12),
              const Text(
                'لا توجد رسوم كيلومتر إضافية لهذا العقد.',
                style: AppTextStyles.caption,
              ),
            ] else ...<Widget>[
              const SizedBox(height: 14),
              AppTextField.money(
                label: 'سعر الكيلومتر الإضافي',
                controller: _extraKmRate,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              if (preview != null) ...<Widget>[
                _row('الكيلومترات المستخدمة', CurrencyFormatter.number(preview.usedKm)),
                _row('الكيلومترات المسموحة', CurrencyFormatter.number(preview.allowedTotal)),
                _row('كيلومتر إضافي', CurrencyFormatter.number(preview.extraKm)),
                _row('رسوم الكيلومتر الإضافي',
                    CurrencyFormatter.format(preview.extraKmCharge),
                    color: AppColors.warning),
                const Divider(height: 24),
                _row('الإجمالي النهائي',
                    CurrencyFormatter.format(preview.finalLineTotal),
                    emphasise: true),
                _row('المتبقي النهائي',
                    CurrencyFormatter.format(preview.finalReceivable),
                    color: preview.finalReceivable > 0.005
                        ? AppColors.danger
                        : AppColors.success),
              ],
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        BlocBuilder<DealsCubit, DealsState>(
          builder: (BuildContext context, DealsState state) {
            return PrimaryButton(
              label: 'إغلاق',
              icon: Icons.check,
              isLoading: state.isSaving,
              onPressed: _canConfirm ? _confirm : null,
            );
          },
        ),
      ],
      backgroundColor: AppColors.white,
    );
  }

  Widget _row(String label, String value, {Color? color, bool emphasise = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: AppTextStyles.body)),
          Text(
            value,
            style: (emphasise ? AppTextStyles.moneyLarge : AppTextStyles.money)
                .copyWith(color: color),
            textDirection: TextDirection.ltr,
          ),
        ],
      ),
    );
  }
}
