import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';

/// Shown when a cubit emits a failure state.
class ErrorStateWidget extends StatelessWidget {
  const ErrorStateWidget({
    super.key,
    required this.message,
    this.title = 'Something went wrong',
    this.onRetry,
    this.retryLabel = 'Try again',
  });

  final String message;
  final String title;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.dangerSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline,
                  size: 30, color: AppColors.danger),
            ),
            const SizedBox(height: 16),
            Text(title, style: AppTextStyles.title, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              message,
              style: AppTextStyles.bodyMuted,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
