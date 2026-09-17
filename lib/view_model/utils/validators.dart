import 'currency_formatter.dart';

/// Form validators. Every message is already display-ready.
class Validators {
  const Validators._();

  static String? notEmpty(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$field is required.';
    }
    return null;
  }

  static String? name(String? value) {
    final String? empty = notEmpty(value, field: 'Name');
    if (empty != null) return empty;
    if (value!.trim().length < 2) {
      return 'Name must be at least 2 characters.';
    }
    return null;
  }

  /// Optional phone. Accepts digits, spaces, +, -, and parentheses.
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final RegExp pattern = RegExp(r'^[0-9+\-\s()]{6,20}$');
    if (!pattern.hasMatch(value.trim())) {
      return 'Enter a valid phone number.';
    }
    return null;
  }

  static String? money(
    String? value, {
    bool isRequired = true,
    bool allowZero = true,
    String field = 'Amount',
  }) {
    if (value == null || value.trim().isEmpty) {
      return isRequired ? '$field is required.' : null;
    }
    final double? parsed = CurrencyFormatter.parse(value);
    if (parsed == null) return 'Enter a valid $field.';
    if (parsed < 0) return '$field cannot be negative.';
    if (!allowZero && parsed == 0) return '$field must be greater than zero.';
    return null;
  }

  static String? quantity(String? value) {
    if (value == null || value.trim().isEmpty) return 'Quantity is required.';
    final int? parsed = int.tryParse(value.trim());
    if (parsed == null) return 'Enter a whole number.';
    if (parsed < 1) return 'Quantity must be at least 1.';
    return null;
  }

  static String? wholeNumber(String? value, {bool isRequired = false}) {
    if (value == null || value.trim().isEmpty) {
      return isRequired ? 'This field is required.' : null;
    }
    if (int.tryParse(value.trim()) == null) return 'Enter a whole number.';
    return null;
  }

  static String? discount(String? value, double subtotal) {
    final String? base = money(value, isRequired: false, field: 'Discount');
    if (base != null) return base;
    final double parsed = CurrencyFormatter.parse(value) ?? 0;
    if (parsed > subtotal) return 'Discount cannot exceed the subtotal.';
    return null;
  }

  static String? dateRange(DateTime? start, DateTime? end) {
    if (start == null || end == null) return null;
    if (end.isBefore(start)) return 'The end date must be after the start date.';
    return null;
  }
}
