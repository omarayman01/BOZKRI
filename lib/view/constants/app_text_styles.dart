import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typography. No explicit font family is set, so the platform default is
/// used — it covers both Arabic and Latin glyphs on macOS and Windows.
class AppTextStyles {
  const AppTextStyles._();

  static const TextStyle displayLarge = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.25,
  );

  static const TextStyle headline = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle title = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.45,
  );

  static const TextStyle bodyMuted = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.45,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    letterSpacing: 0.2,
  );

  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
  );

  /// Table headers on the dense list screens.
  static const TextStyle tableHeader = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.deepNavy,
  );

  static const TextStyle tableCell = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  /// Money figures. Western digits in both locales; a tabular feature keeps
  /// columns aligned.
  static const TextStyle money = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  static const TextStyle moneyLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.deepNavy,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  static TextStyle profit(double value) => money.copyWith(
        color: value >= 0 ? AppColors.success : AppColors.danger,
        fontWeight: FontWeight.w700,
      );

  static const TextStyle navItem = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.white,
  );
}
