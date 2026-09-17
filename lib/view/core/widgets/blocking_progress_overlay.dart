import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';

/// Full-screen dim + spinner + status text, shown while a long disk
/// operation runs (backup, restore, Excel export, End-of-Day Save).
///
/// Wrap the screen's content in this widget and toggle [visible]; it never
/// removes [child] from the tree, it only paints a blocking layer on top so
/// the underlying screen keeps its scroll position and state.
class BlockingProgressOverlay extends StatelessWidget {
  const BlockingProgressOverlay({
    super.key,
    required this.visible,
    required this.child,
    this.statusText,
  });

  final bool visible;
  final Widget child;

  /// Current step, e.g. "Writing Excel report…". Null shows a bare spinner.
  final String? statusText;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        child,
        if (visible)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: false,
              child: Container(
                color: AppColors.deepNavy.withValues(alpha: 0.55),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const CircularProgressIndicator(color: AppColors.white),
                    if (statusText != null) ...<Widget>[
                      const SizedBox(height: 16),
                      Text(
                        statusText!,
                        style: AppTextStyles.body
                            .copyWith(color: AppColors.white),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
