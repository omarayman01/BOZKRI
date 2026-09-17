import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import 'primary_button.dart';

/// Blocking yes/no confirmation. Returns true only when confirmed.
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'تأكيد',
    this.cancelLabel = 'إلغاء',
    this.isDestructive = false,
    this.warning,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;

  /// Extra highlighted note, e.g. that balances will be recalculated.
  final String? warning;

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'تأكيد',
    String cancelLabel = 'إلغاء',
    bool isDestructive = false,
    String? warning,
  }) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext _) => ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
        warning: warning,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title, style: AppTextStyles.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(message, style: AppTextStyles.body),
            if (warning != null) ...<Widget>[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(Icons.warning_amber_rounded,
                        size: 18, color: AppColors.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(warning!, style: AppTextStyles.caption),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        PrimaryButton(
          label: confirmLabel,
          isDestructive: isDestructive,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
