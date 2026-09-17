import 'package:flutter/material.dart';

/// The fixed brand palette plus semantic status colors.
class AppColors {
  const AppColors._();

  // ---- Brand ----
  /// Side-nav background, app bar, primary text.
  static const Color deepNavy = Color(0xFF061E29);

  /// Primary buttons, active nav item.
  static const Color primary = Color(0xFF1D546D);

  /// Secondary actions, icons, borders, chips.
  static const Color secondary = Color(0xFF5F9598);

  /// Content background, cards.
  static const Color surface = Color(0xFFF3F4F4);

  static const Color white = Color(0xFFFFFFFF);

  // ---- Semantic ----
  /// Profit / paid.
  static const Color success = Color(0xFF4C8B6B);
  static const Color successSurface = Color(0xFFE4F0EA);

  /// Loss / expired / unpaid / used.
  static const Color danger = Color(0xFFB4534B);
  static const Color dangerSurface = Color(0xFFF6E6E4);

  /// Partial / expiring.
  static const Color warning = Color(0xFFC58A3A);
  static const Color warningSurface = Color(0xFFFAF0E1);

  // ---- Neutrals ----
  static const Color textPrimary = deepNavy;
  static const Color textSecondary = Color(0xFF4A5B64);
  static const Color textDisabled = Color(0xFF8A979E);
  static const Color border = Color(0xFFD6DCDD);
  static const Color divider = Color(0xFFE3E7E8);
  static const Color scrim = Color(0x66061E29);
}
