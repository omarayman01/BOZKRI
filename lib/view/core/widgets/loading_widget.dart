import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';

/// The single loading state used by every cubit-driven screen.
class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              color: AppColors.primary,
            ),
          ),
          if (message != null) ...<Widget>[
            const SizedBox(height: 14),
            Text(message!, style: AppTextStyles.bodyMuted),
          ],
        ],
      ),
    );
  }
}
