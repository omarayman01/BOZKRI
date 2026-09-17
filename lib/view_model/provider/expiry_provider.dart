import 'package:flutter/foundation.dart';

import '../../model/item_model.dart';
import '../../model/transaction_item_model.dart';
import '../utils/date_utils.dart';

/// Severity of an expiry date relative to the configured warning window.
enum ExpiryLevel { none, expiring, expired }

/// Tracks items flagged as expiring or already expired, and exposes the badge
/// count shown on the side-nav and the dashboard expiry panel.
class ExpiryProvider extends ChangeNotifier {
  ExpiryProvider({int warningDays = 30}) : _warningDays = warningDays;

  int _warningDays;
  List<ItemModel> _supplierItems = <ItemModel>[];
  List<TransactionItemModel> _clientLines = <TransactionItemModel>[];

  int get warningDays => _warningDays;

  /// Supplier-side items with an expiry date inside the window or past it.
  List<ItemModel> get flaggedItems => _supplierItems
      .where((ItemModel i) => levelForDate(i.expiryDate) != ExpiryLevel.none)
      .toList()
    ..sort((ItemModel a, ItemModel b) =>
        a.expiryDate!.compareTo(b.expiryDate!));

  List<ItemModel> get expiredItems => _supplierItems
      .where((ItemModel i) => levelForDate(i.expiryDate) == ExpiryLevel.expired)
      .toList();

  List<ItemModel> get expiringItems => _supplierItems
      .where((ItemModel i) => levelForDate(i.expiryDate) == ExpiryLevel.expiring)
      .toList();

  /// Client-side lines carrying their own expiry date.
  List<TransactionItemModel> get flaggedClientLines => _clientLines
      .where((TransactionItemModel l) =>
          levelForDate(l.expiryDate) != ExpiryLevel.none)
      .toList();

  /// Number rendered in the nav / dashboard badge.
  int get badgeCount => flaggedItems.length;

  bool get hasFlags => badgeCount > 0;

  ExpiryLevel levelForDate(DateTime? date) {
    if (date == null) return ExpiryLevel.none;
    if (AppDateUtils.isExpired(date)) return ExpiryLevel.expired;
    if (AppDateUtils.isExpiringWithin(date, _warningDays)) {
      return ExpiryLevel.expiring;
    }
    return ExpiryLevel.none;
  }

  ExpiryLevel levelForItem(ItemModel item) => levelForDate(item.expiryDate);

  ExpiryLevel levelForLine(TransactionItemModel line) =>
      levelForDate(line.expiryDate);

  /// Days remaining, negative when overdue. Null when there is no expiry.
  int? daysRemaining(DateTime? date) =>
      date == null ? null : AppDateUtils.daysUntil(date);

  void setWarningDays(int days) {
    final int clamped = days.clamp(1, 365);
    if (_warningDays == clamped) return;
    _warningDays = clamped;
    notifyListeners();
  }

  /// Replaces the tracked supplier-side items. Called by ItemsCubit after any
  /// item load or mutation.
  void setItems(List<ItemModel> items) {
    _supplierItems = items
        .where((ItemModel i) => i.isActive && i.expiryDate != null)
        .toList();
    notifyListeners();
  }

  void setClientLines(List<TransactionItemModel> lines) {
    _clientLines = lines
        .where((TransactionItemModel l) => l.expiryDate != null)
        .toList();
    notifyListeners();
  }

  void clear() {
    _supplierItems = <ItemModel>[];
    _clientLines = <TransactionItemModel>[];
    notifyListeners();
  }
}
