import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../../../model/payment_model.dart';
import '../../../../model/transaction_item_model.dart';
import '../../../../model/transaction_with_items_model.dart';
import '../../../../view_model/cubit/payments/payments_cubit.dart';
import '../../../../view_model/utils/currency_formatter.dart';
import '../../../../view_model/utils/date_utils.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_text_styles.dart';
import '../../../core/widgets/confirm_dialog.dart';
import 'add_payment_dialog.dart';

/// One cell per rental day on a per-day priced line (e.g. a car). Tapping an
/// unpaid day records one payment for it; tapping a paid day offers to
/// unmark it. The grid never stores its own schedule — every cell's state
/// comes straight from `payments`.
class PerDayRentalGrid extends StatelessWidget {
  const PerDayRentalGrid({
    super.key,
    required this.deal,
    required this.line,
    required this.onChanged,
  });

  final TransactionWithItemsModel deal;
  final TransactionItemModel line;

  /// Called after a day is successfully marked or unmarked, so the caller can
  /// reload the deal (this widget only holds the snapshot it was built with).
  final VoidCallback onChanged;

  List<DateTime> get _days {
    final DateTime? start = line.rentStart;
    final int count = line.days ?? 0;
    if (start == null || count <= 0) return const <DateTime>[];
    final DateTime base = DateTime(start.year, start.month, start.day);
    return List<DateTime>.generate(count, (int i) => base.add(Duration(days: i)));
  }

  Future<void> _markPaid(BuildContext context, DateTime day) async {
    final PaymentMethod? method = await showDialog<PaymentMethod>(
      context: context,
      builder: (BuildContext _) => _MethodPickerDialog(
        amount: line.pricePerDay ?? 0,
        day: day,
      ),
    );
    if (method == null || !context.mounted) return;

    final bool ok = await context.read<PaymentsCubit>().markRentalDayPaid(
          transactionId: deal.id,
          transactionItemId: line.id,
          rentalDayDate: day,
          amount: line.pricePerDay ?? 0,
          method: method,
        );
    if (ok) onChanged();
  }

  Future<void> _unmarkPaid(BuildContext context, DateTime day) async {
    final List<PaymentModel> matches = deal.payments
        .where((PaymentModel p) =>
            p.transactionItemId == line.id &&
            p.rentalDayDate != null &&
            _sameDay(p.rentalDayDate!, day))
        .toList();
    if (matches.isEmpty) return;
    final PaymentModel payment = matches.first;

    final bool ok = await ConfirmDialog.show(
      context,
      title: 'إلغاء تعليم هذا اليوم كمدفوع؟',
      message: 'سيتم حذف الدفعة المسجلة ليوم ${AppDateUtils.formatDate(day)}.',
      confirmLabel: 'إلغاء التعليم',
      isDestructive: true,
    );
    if (!ok || !context.mounted) return;

    final bool deleted =
        await context.read<PaymentsCubit>().deletePayment(payment.id, deal.id);
    if (deleted) onChanged();
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final List<DateTime> days = _days;
    if (days.isEmpty) return const SizedBox.shrink();

    final Set<DateTime> paid = deal.paidRentalDaysFor(line.id);
    final int paidCount = deal.paidDaysFor(line);
    final int unpaidCount = deal.unpaidDaysFor(line);
    final double receivable = deal.lineReceivableFor(line);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              'أيام الإيجار: $paidCount / ${days.length} مدفوع'
              '${unpaidCount > 0 ? ' · $unpaidCount غير مدفوع' : ''}',
              style: AppTextStyles.label,
            ),
            const Spacer(),
            Text(
              'المتبقي على السطر: ${CurrencyFormatter.format(receivable)}',
              style: AppTextStyles.money.copyWith(
                color:
                    receivable > 0.005 ? AppColors.danger : AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final DateTime day in days)
              _DayCell(
                day: day,
                isPaid: paid.any((DateTime d) => _sameDay(d, day)),
                onTap: () => paid.any((DateTime d) => _sameDay(d, day))
                    ? _unmarkPaid(context, day)
                    : _markPaid(context, day),
              ),
          ],
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.isPaid, required this.onTap});

  final DateTime day;
  final bool isPaid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 64,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isPaid ? AppColors.successSurface : AppColors.dangerSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: (isPaid ? AppColors.success : AppColors.danger)
                .withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              isPaid ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16,
              color: isPaid ? AppColors.success : AppColors.danger,
            ),
            const SizedBox(height: 4),
            Text(
              AppDateUtils.formatShort(day),
              style: AppTextStyles.caption,
              textDirection: TextDirection.ltr,
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodPickerDialog extends StatefulWidget {
  const _MethodPickerDialog({required this.amount, required this.day});

  final double amount;
  final DateTime day;

  @override
  State<_MethodPickerDialog> createState() => _MethodPickerDialogState();
}

class _MethodPickerDialogState extends State<_MethodPickerDialog> {
  PaymentMethod _method = PaymentMethod.cash;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('تعليم يوم ${AppDateUtils.formatDate(widget.day)} كمدفوع',
          style: AppTextStyles.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'المبلغ: ${CurrencyFormatter.format(widget.amount)}',
              style: AppTextStyles.body,
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
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_method),
          child: const Text('تعليم كمدفوع'),
        ),
      ],
    );
  }
}
