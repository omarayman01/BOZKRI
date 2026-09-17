import 'package:flutter/material.dart';

/// Global, compile-time constants for the application.
class AppConstants {
  const AppConstants._();

  // ---- Identity ----
  static const String appNameAr = 'نظام إدارة الوكالة';

  /// Dropped in by the admin — see assets/branding/README.md. Every widget
  /// that shows the logo must fall back gracefully when this file is absent.
  static const String appLogoAsset = 'assets/branding/app_logo.png';

  // ---- Desktop window ----
  static const Size minWindowSize = Size(1100, 720);
  static const Size initialWindowSize = Size(1440, 900);

  // ---- Currency ----
  static const String currencyCode = 'EGP';
  static const String currencySymbol = 'EGP';
  static const int currencyDecimalDigits = 2;

  // ---- Locale ----
  // Arabic-only, RTL-only — there is no language toggle.
  static const Locale localeAr = Locale('ar');
  static const List<Locale> supportedLocales = <Locale>[localeAr];

  /// Numeric digits stay Western (LTR) even in the Arabic UI.
  static const String numberLocaleEn = 'en_US';

  // ---- Database ----
  static const String dbFileName = 'agency_management.sqlite';
  static const String backupFileExtension = 'sqlite';

  // ---- Expiry ----
  /// Default expiry-warning window in days (overridable in Settings).
  static const int defaultExpiryWarningDays = 30;

  // ---- Persistence keys (SharedPreferences) ----
  static const String prefsExpiryWindowKey = 'settings.expiryWarningDays';

  // ---- Layout ----
  static const double navRailWidth = 232;
  static const double navRailCollapsedWidth = 72;
  static const double contentPadding = 24;
  static const double cardRadius = 12;
  static const double denseRowHeight = 44;
}
