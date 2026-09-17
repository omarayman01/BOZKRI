import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../view/constants/app_constants.dart';

/// Shared, persisted app settings: the expiry-warning window. Currency is
/// fixed to EGP; the app is Arabic-only, so there is no language setting
/// here. Backup/restore destinations are fixed paths (Phase 6), not an
/// admin preference, so they are not stored here.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._prefs) {
    _load();
  }

  final SharedPreferences _prefs;

  int _expiryWarningDays = AppConstants.defaultExpiryWarningDays;

  int get expiryWarningDays => _expiryWarningDays;

  String get currencyCode => AppConstants.currencyCode;

  void _load() {
    _expiryWarningDays = _prefs.getInt(AppConstants.prefsExpiryWindowKey) ??
        AppConstants.defaultExpiryWarningDays;
  }

  Future<void> setExpiryWarningDays(int days) async {
    final int clamped = days.clamp(1, 365);
    if (_expiryWarningDays == clamped) return;
    _expiryWarningDays = clamped;
    notifyListeners();
    await _prefs.setInt(AppConstants.prefsExpiryWindowKey, clamped);
  }
}
