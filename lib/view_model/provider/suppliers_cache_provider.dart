import 'package:flutter/foundation.dart';

import '../../model/supplier_model.dart';

/// Shared in-memory supplier list, mirroring [ClientsCacheProvider].
class SuppliersCacheProvider extends ChangeNotifier {
  List<SupplierModel> _suppliers = <SupplierModel>[];

  List<SupplierModel> get suppliers =>
      List<SupplierModel>.unmodifiable(_suppliers);

  /// Excludes the seeded "بوزكري (بدون مورد)" system supplier — it is never
  /// a real pick in a picker, only ever auto-derived from a supplier-less
  /// car (see DealLineEditor).
  List<SupplierModel> get activeSuppliers => _suppliers
      .where((SupplierModel s) => s.isActive && !s.isSystemSupplier)
      .toList();

  bool get isEmpty => _suppliers.isEmpty;

  /// The seeded "بوزكري (بدون مورد)" supplier's id — used to assign a car
  /// that has no real supplier. Null only in the brief window before the
  /// cache is first populated.
  int? get systemSupplierId {
    for (final SupplierModel s in _suppliers) {
      if (s.isSystemSupplier) return s.id;
    }
    return null;
  }

  SupplierModel? byId(int id) {
    for (final SupplierModel s in _suppliers) {
      if (s.id == id) return s;
    }
    return null;
  }

  String nameOf(int id) => byId(id)?.name ?? '';

  List<SupplierModel> search(String query) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) return activeSuppliers;
    return _suppliers
        .where((SupplierModel s) =>
            !s.isSystemSupplier &&
            (s.name.toLowerCase().contains(q) ||
                (s.phone ?? '').toLowerCase().contains(q)))
        .toList();
  }

  void setSuppliers(List<SupplierModel> suppliers) {
    _suppliers = List<SupplierModel>.from(suppliers);
    notifyListeners();
  }

  void upsert(SupplierModel supplier) {
    final int index =
        _suppliers.indexWhere((SupplierModel s) => s.id == supplier.id);
    if (index >= 0) {
      _suppliers[index] = supplier;
    } else {
      _suppliers.add(supplier);
    }
    _suppliers
        .sort((SupplierModel a, SupplierModel b) => a.name.compareTo(b.name));
    notifyListeners();
  }

  void remove(int id) {
    _suppliers.removeWhere((SupplierModel s) => s.id == id);
    notifyListeners();
  }

  void clear() {
    _suppliers = <SupplierModel>[];
    notifyListeners();
  }
}
