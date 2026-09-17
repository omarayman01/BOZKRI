import 'package:flutter/material.dart';

import '../../../model/payment_model.dart';
import '../../../model/transaction_model.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';

/// Derived payment status: unpaid (red), partial (amber), paid (green).
class PaymentStatusChip extends StatelessWidget {
  const PaymentStatusChip({super.key, required this.status, this.compact = false});

  final PaymentStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    late final Color foreground;
    late final Color background;
    late final String label;

    switch (status) {
      case PaymentStatus.paid:
        foreground = AppColors.success;
        background = AppColors.successSurface;
        label = 'مدفوع';
      case PaymentStatus.partial:
        foreground = AppColors.warning;
        background = AppColors.warningSurface;
        label = 'جزئي';
      case PaymentStatus.unpaid:
        foreground = AppColors.danger;
        background = AppColors.dangerSurface;
        label = 'غير مدفوع';
    }

    return _Pill(
      label: label,
      foreground: foreground,
      background: background,
      compact: compact,
    );
  }
}

/// Deal status: active / partially refunded / fully refunded.
class DealStatusChip extends StatelessWidget {
  const DealStatusChip({super.key, required this.status, this.compact = false});

  final TransactionStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    late final Color foreground;
    late final Color background;
    late final String label;

    switch (status) {
      case TransactionStatus.active:
        foreground = AppColors.primary;
        background = AppColors.surface;
        label = 'ساري';
      case TransactionStatus.partiallyRefunded:
        foreground = AppColors.warning;
        background = AppColors.warningSurface;
        label = 'مسترجع جزئياً';
      case TransactionStatus.fullyRefunded:
        foreground = AppColors.danger;
        background = AppColors.dangerSurface;
        label = 'مسترجع بالكامل';
    }

    return _Pill(
      label: label,
      foreground: foreground,
      background: background,
      compact: compact,
    );
  }
}

/// Car-line contract status (حالة العقد): ساري (open, green) / مغلق
/// (closed, grey) — the same wording and colors as `LineItemTile`'s badge,
/// centralized here so the deals list can show it too.
class LineStatusChip extends StatelessWidget {
  const LineStatusChip({super.key, required this.closed, this.compact = false});

  final bool closed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _Pill(
      label: closed ? 'مغلق' : 'ساري',
      foreground: closed ? AppColors.textSecondary : AppColors.success,
      background: closed ? AppColors.surface : AppColors.successSurface,
      compact: compact,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.foreground,
    required this.background,
    required this.compact,
  });

  final String label;
  final Color foreground;
  final Color background;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: foreground.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
