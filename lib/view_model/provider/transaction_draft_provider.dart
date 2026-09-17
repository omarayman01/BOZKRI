import 'package:flutter/foundation.dart';

import '../../model/client_model.dart';
import '../../model/item_model.dart';
import '../../model/payment_model.dart';
import '../../model/transaction_item_model.dart';
import '../../model/transaction_with_items_model.dart';
import '../database/local/daos/transactions_dao.dart';
import '../../model/transaction_model.dart';

/// The deal currently being built or edited: selected client, line items,
/// discount and the live totals shown in the builder footer.
///
/// The draft is cleared only after a successful commit.
class TransactionDraftProvider extends ChangeNotifier {
  int? _editingTransactionId;
  ClientModel? _client;
  DealType _dealType = DealType.sell;
  final List<DealLineInput> _lines = <DealLineInput>[];
  double _discount = 0;
  DateTime _dateTime = DateTime.now();
  String? _notes;
  String? _commissionName;
  double? _commissionAmount;
  PaymentStatus? _paymentStatusOverride;

  // ---- Reads ----

  int? get editingTransactionId => _editingTransactionId;
  bool get isEditing => _editingTransactionId != null;

  ClientModel? get client => _client;
  int? get clientId => _client?.id;

  DealType get dealType => _dealType;
  bool get isRent => _dealType == DealType.rent;

  List<DealLineInput> get lines => List<DealLineInput>.unmodifiable(_lines);
  bool get hasLines => _lines.isNotEmpty;

  double get discount => _discount;
  DateTime get dateTime => _dateTime;
  String? get notes => _notes;
  String? get commissionName => _commissionName;
  double? get commissionAmount => _commissionAmount;
  PaymentStatus? get paymentStatusOverride => _paymentStatusOverride;

  /// Ready to commit: a client and at least one line.
  bool get canCommit => _client != null && _lines.isNotEmpty;

  // ---- Live totals ----

  double get subtotal =>
      _lines.fold<double>(0, (double sum, DealLineInput l) => sum + l.lineTotal);

  double get totalCost =>
      _lines.fold<double>(0, (double sum, DealLineInput l) => sum + l.lineCost);

  double get total => subtotal - _discount;

  double get profit => total - totalCost;

  Set<int> get supplierIds =>
      _lines.map((DealLineInput l) => l.supplierId).toSet();

  /// Item ids already on the draft, so the picker can grey them out.
  Set<int> get usedItemIds => _lines.map((DealLineInput l) => l.itemId).toSet();

  // ---- Mutations ----

  void setClient(ClientModel? client) {
    _client = client;
    notifyListeners();
  }

  void setDealType(DealType type) {
    _dealType = type;
    for (int i = 0; i < _lines.length; i++) {
      _lines[i] = _lines[i].copyWith(
        dealType: type,
        clearRent: type != DealType.rent,
      );
    }
    notifyListeners();
  }

  void setDiscount(double value) {
    _discount = value < 0 ? 0 : value;
    notifyListeners();
  }

  void setDateTime(DateTime value) {
    _dateTime = value;
    notifyListeners();
  }

  void setNotes(String? value) {
    _notes = (value == null || value.trim().isEmpty) ? null : value.trim();
    notifyListeners();
  }

  void setCommissionName(String? value) {
    _commissionName = (value == null || value.trim().isEmpty) ? null : value.trim();
    notifyListeners();
  }

  void setCommissionAmount(double? value) {
    _commissionAmount = (value == null || value <= 0) ? null : value;
    notifyListeners();
  }

  void setPaymentStatusOverride(PaymentStatus? value) {
    _paymentStatusOverride = value;
    notifyListeners();
  }

  /// Adds a line, prefilling the editable cost/price snapshots and the
  /// per-line expiry from the item's defaults.
  void addLineFromItem(ItemModel item, {int qty = 1}) {
    _lines.add(
      DealLineInput(
        itemId: item.id,
        supplierId: item.supplierId,
        dealType: _dealType,
        qty: qty,
        unitCost: item.defaultCost ?? 0,
        unitPrice: item.defaultPrice ?? 0,
        expiryDate: item.expiryDate,
        isSingleUse: item.isSingleUse,
        itemLabel: item.label,
        supplierName: item.supplierName,
      ),
    );
    notifyListeners();
  }

  void addLine(DealLineInput line) {
    _lines.add(line);
    notifyListeners();
  }

  void updateLine(int index, DealLineInput line) {
    if (index < 0 || index >= _lines.length) return;
    _lines[index] = line;
    notifyListeners();
  }

  void removeLine(int index) {
    if (index < 0 || index >= _lines.length) return;
    _lines.removeAt(index);
    notifyListeners();
  }

  // ---- Lifecycle ----

  /// Starts a fresh draft.
  void startNew() {
    _editingTransactionId = null;
    _client = null;
    _dealType = DealType.sell;
    _lines.clear();
    _discount = 0;
    _dateTime = DateTime.now();
    _notes = null;
    _commissionName = null;
    _commissionAmount = null;
    _paymentStatusOverride = null;
    notifyListeners();
  }

  /// Loads an existing deal into the draft for editing. Line values come from
  /// the stored snapshots, not from the live items.
  void loadForEdit(TransactionWithItemsModel deal, {ClientModel? client}) {
    _editingTransactionId = deal.transaction.id;
    _client = client;
    _dealType = deal.transaction.dealType;
    _discount = deal.transaction.discount;
    _dateTime = deal.transaction.dateTime;
    _notes = deal.transaction.notes;
    _commissionName = deal.transaction.commissionName;
    _commissionAmount = deal.transaction.commissionAmount;
    _paymentStatusOverride = deal.transaction.paymentStatusOverride;
    _lines
      ..clear()
      ..addAll(deal.items.map((TransactionItemModel l) => DealLineInput(
            existingLineId: l.id,
            itemId: l.itemId,
            supplierId: l.supplierId,
            dealType: l.dealType,
            qty: l.qty,
            unitCost: l.unitCost,
            unitPrice: l.unitPrice,
            rentStart: l.rentStart,
            rentEnd: l.rentEnd,
            expiryDate: l.expiryDate,
            notes: l.notes,
            isSingleUse: l.isSingleUse,
            itemLabel: l.itemLabel,
            supplierName: l.supplierName,
            pricePerDay: l.pricePerDay,
            costPerDay: l.costPerDay,
            days: l.days,
            allowedKmPerDay: l.allowedKmPerDay,
            extraKmRate: l.extraKmRate,
            pickupKilometer: l.pickupKilometer,
            returnKilometer: l.returnKilometer,
            extraKmCharge: l.extraKmCharge,
            lineStatus: l.lineStatus,
          )));
    notifyListeners();
  }

  /// Called only after a successful commit or edit.
  void clear() => startNew();
}
