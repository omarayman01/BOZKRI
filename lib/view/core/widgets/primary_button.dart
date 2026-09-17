import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';

/// The app's main call-to-action, with a built-in busy state so callers never
/// have to swap the child for a spinner themselves.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isDestructive = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isDestructive;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final ButtonStyle style = ElevatedButton.styleFrom(
      backgroundColor: isDestructive ? AppColors.danger : AppColors.primary,
      foregroundColor: AppColors.white,
    );

    final Widget child = isLoading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: AppColors.white,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Text(label),
            ],
          );

    final Widget button = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: style,
      child: child,
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Lower-emphasis companion to [PrimaryButton].
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final Widget button = OutlinedButton(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 18),
            const SizedBox(width: 8),
          ],
          Text(label),
        ],
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
