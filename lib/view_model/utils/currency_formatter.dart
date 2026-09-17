import 'package:intl/intl.dart';

import '../../view/constants/app_constants.dart';

/// EGP formatting. Digits stay Western (LTR) even when the UI is Arabic, so
/// the number locale is pinned to en_US regardless of the app locale.
class CurrencyFormatter {
  const CurrencyFormatter._();

  static final NumberFormat _currency = NumberFormat.currency(
    locale: AppConstants.numberLocaleEn,
    symbol: '${AppConstants.currencySymbol} ',
    decimalDigits: AppConstants.currencyDecimalDigits,
  );

  static final NumberFormat _compact = NumberFormat.compactCurrency(
    locale: AppConstants.numberLocaleEn,
    symbol: '${AppConstants.currencySymbol} ',
    decimalDigits: 1,
  );

  static final NumberFormat _plain = NumberFormat.decimalPattern(
    AppConstants.numberLocaleEn,
  );

  /// "EGP 1,250.00"
  static String format(num value) => _currency.format(value);

  /// "EGP 1.3K" — for chart axes and tight KPI cards.
  static String compact(num value) => _compact.format(value);

  /// "1,250" — no currency symbol.
  static String number(num value) => _plain.format(value);

  /// Signed, for profit figures: "+EGP 300.00" / "-EGP 300.00".
  static String signed(num value) {
    final String formatted = format(value.abs());
    if (value > 0) return '+$formatted';
    if (value < 0) return '-$formatted';
    return formatted;
  }

  /// Parses user input that may contain grouping separators or the symbol.
  static double? parse(String? input) {
    if (input == null) return null;
    final String cleaned = input
        .replaceAll(AppConstants.currencySymbol, '')
        .replaceAll(',', '')
        .replaceAll('٫', '.')
        .replaceAll('٬', '')
        .trim();
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }
}
