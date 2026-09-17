import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_constants.dart';
import 'app_text_styles.dart';

/// The single light theme. Density is dense on tables and comfortable on
/// forms; individual screens opt into the dense variant where needed.
class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    const ColorScheme scheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.white,
      secondary: AppColors.secondary,
      onSecondary: AppColors.white,
      surface: AppColors.white,
      onSurface: AppColors.textPrimary,
      error: AppColors.danger,
      onError: AppColors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.surface,
      dividerColor: AppColors.divider,
      visualDensity: VisualDensity.standard,

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.deepNavy,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
              fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.white,
        ),
      ),

      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.cardRadius),
          side: const BorderSide(color: AppColors.border),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.textDisabled,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          textStyle: AppTextStyles.button,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.secondary),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: AppTextStyles.button,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTextStyles.button,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        isDense: false,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        labelStyle: AppTextStyles.label,
        hintStyle: AppTextStyles.bodyMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.6),
        ),
      ),

      dataTableTheme: const DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll<Color>(AppColors.surface),
        headingTextStyle: AppTextStyles.tableHeader,
        dataTextStyle: AppTextStyles.tableCell,
        dividerThickness: 1,
        columnSpacing: 28,
        horizontalMargin: 16,
        headingRowHeight: 44,
        dataRowMinHeight: AppConstants.denseRowHeight,
        dataRowMaxHeight: 56,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.border),
        labelStyle: AppTextStyles.caption,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        ),
        titleTextStyle: AppTextStyles.title,
        contentTextStyle: AppTextStyles.body,
      ),

      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        labelStyle: AppTextStyles.button,
        unselectedLabelStyle: AppTextStyles.subtitle,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.deepNavy,
        contentTextStyle: AppTextStyles.body.copyWith(color: AppColors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      textTheme: const TextTheme(
        displayLarge: AppTextStyles.displayLarge,
        headlineSmall: AppTextStyles.headline,
        titleLarge: AppTextStyles.title,
        titleMedium: AppTextStyles.subtitle,
        bodyMedium: AppTextStyles.body,
        bodySmall: AppTextStyles.caption,
        labelLarge: AppTextStyles.label,
      ),
    );
  }

  /// Dense variant for list screens with data tables.
  static ThemeData dense() =>
      light().copyWith(visualDensity: VisualDensity.compact);
}
