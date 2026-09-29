import 'package:equatable/equatable.dart';

import '../../../model/supplier_model.dart';

enum SuppliersStatus { initial, loading, success, failure }

class SuppliersState extends Equatable {
  const SuppliersState({
    this.status = SuppliersStatus.initial,
    this.suppliers = const <SupplierModel>[],
    this.query = '',
    this.errorMessage,
    this.isSaving = false,
  });

  final SuppliersStatus status;
  final List<SupplierModel> suppliers;
  final String query;
  final String? errorMessage;
  final bool isSaving;

  bool get isLoading => status == SuppliersStatus.loading;
  bool get isFailure => status == SuppliersStatus.failure;
  bool get isEmpty => status == SuppliersStatus.success && suppliers.isEmpty;

  /// Never lists the seeded "بوزكري (بدون مورد)" system supplier — it isn't
  /// a real business supplier to manage from this screen.
  List<SupplierModel> get visibleSuppliers {
    final List<SupplierModel> real =
        suppliers.where((SupplierModel s) => !s.isSystemSupplier).toList();
    if (query.trim().isEmpty) return real;
    final String q = query.trim().toLowerCase();
    return real
        .where((SupplierModel s) =>
            s.name.toLowerCase().contains(q) ||
            (s.phone ?? '').toLowerCase().contains(q))
        .toList();
  }

  SuppliersState copyWith({
    SuppliersStatus? status,
    List<SupplierModel>? suppliers,
    String? query,
    String? errorMessage,
    bool? isSaving,
    bool clearError = false,
  }) {
    return SuppliersState(
      status: status ?? this.status,
      suppliers: suppliers ?? this.suppliers,
      query: query ?? this.query,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSaving: isSaving ?? this.isSaving,
    );
  }

  @override
  List<Object?> get props =>
      <Object?>[status, suppliers, query, errorMessage, isSaving];
}
