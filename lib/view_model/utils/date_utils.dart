import 'package:intl/intl.dart';

import '../../view/constants/app_constants.dart';

/// Date formatting and range helpers. Dates render with Western numerals in
/// both locales to stay consistent with currency figures.
class AppDateUtils {
  const AppDateUtils._();

  static final DateFormat _date =
      DateFormat('dd MMM yyyy', AppConstants.numberLocaleEn);
  static final DateFormat _dateTime =
      DateFormat('dd MMM yyyy  HH:mm', AppConstants.numberLocaleEn);
  static final DateFormat _short =
      DateFormat('dd/MM', AppConstants.numberLocaleEn);
  static final DateFormat _month =
      DateFormat('MMM yyyy', AppConstants.numberLocaleEn);

  static String formatDate(DateTime value) => _date.format(value);
  static String formatDateTime(DateTime value) => _dateTime.format(value);
  static String formatShort(DateTime value) => _short.format(value);
  static String formatMonth(DateTime value) => _month.format(value);

  static String formatNullable(DateTime? value, {String fallback = '—'}) =>
      value == null ? fallback : formatDate(value);

  static DateTime startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime endOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day, 23, 59, 59, 999);

  static DateTime startOfMonth(DateTime value) =>
      DateTime(value.year, value.month);

  static DateTime endOfMonth(DateTime value) =>
      endOfDay(DateTime(value.year, value.month + 1, 0));

  /// Whole days from today until [date]; negative when already past.
  static int daysUntil(DateTime date) =>
      startOfDay(date).difference(startOfDay(DateTime.now())).inDays;

  static bool isExpired(DateTime? date) =>
      date != null && daysUntil(date) < 0;

  static bool isExpiringWithin(DateTime? date, int days) {
    if (date == null) return false;
    final int remaining = daysUntil(date);
    return remaining >= 0 && remaining <= days;
  }

  static AppDateRange currentMonth() {
    final DateTime now = DateTime.now();
    return AppDateRange(start: startOfMonth(now), end: endOfDay(now));
  }

  static AppDateRange lastNDays(int days) {
    final DateTime now = DateTime.now();
    return AppDateRange(
      start: startOfDay(now.subtract(Duration(days: days - 1))),
      end: endOfDay(now),
    );
  }
}

/// A plain from/to pair, independent of Flutter's material AppDateRange so it
/// can be used from the view_model layer.
class AppDateRange {
  const AppDateRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  int get days => end.difference(start).inDays + 1;

  AppDateRange copyWith({DateTime? start, DateTime? end}) =>
      AppDateRange(start: start ?? this.start, end: end ?? this.end);

  @override
  bool operator ==(Object other) =>
      other is AppDateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}
