import 'package:equatable/equatable.dart';

import '../../../model/transaction_with_items_model.dart';

enum DealsStatus { initial, loading, success, failure }

class DealsState extends Equatable {
  const DealsState({
    this.status = DealsStatus.initial,
    this.deals = const <TransactionWithItemsModel>[],
    this.selectedDeal,
    this.query = '',
    this.errorMessage,
    this.isSaving = false,
    this.lastCommittedId,
    this.unavailableItemLabel,
  });

  final DealsStatus status;
  final List<TransactionWithItemsModel> deals;
  final TransactionWithItemsModel? selectedDeal;
  final String query;
  final String? errorMessage;
  final bool isSaving;

  /// Set after a successful commit so the caller can navigate to the detail.
  final int? lastCommittedId;

  /// Populated when a commit was rejected by the single-use re-check.
  final String? unavailableItemLabel;

  bool get isLoading => status == DealsStatus.loading;
  bool get isFailure => status == DealsStatus.failure;
  bool get isEmpty => status == DealsStatus.success && deals.isEmpty;

  static String _normalizePhone(String value) =>
      value.replaceAll(RegExp(r'[\s-]'), '');

  List<TransactionWithItemsModel> get visibleDeals {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) return deals;
    final String qPhone = _normalizePhone(q);
    return deals.where((TransactionWithItemsModel d) {
      final String client = (d.transaction.clientName ?? '').toLowerCase();
      final String clientPhone =
          _normalizePhone((d.transaction.clientPhone ?? '').toLowerCase());
      final String suppliers = d.supplierNames.join(' ').toLowerCase();
      final String supplierPhones = d.supplierPhones
          .map((String p) => _normalizePhone(p.toLowerCase()))
          .join(' ');
      return client.contains(q) ||
          suppliers.contains(q) ||
          d.id.toString() == q ||
          (qPhone.isNotEmpty && clientPhone.contains(qPhone)) ||
          (qPhone.isNotEmpty && supplierPhones.contains(qPhone));
    }).toList();
  }

  DealsState copyWith({
    DealsStatus? status,
    List<TransactionWithItemsModel>? deals,
    TransactionWithItemsModel? selectedDeal,
    String? query,
    String? errorMessage,
    bool? isSaving,
    int? lastCommittedId,
    String? unavailableItemLabel,
    bool clearError = false,
    bool clearSelection = false,
    bool clearCommitted = false,
  }) {
    return DealsState(
      status: status ?? this.status,
      deals: deals ?? this.deals,
      selectedDeal: clearSelection ? null : (selectedDeal ?? this.selectedDeal),
      query: query ?? this.query,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSaving: isSaving ?? this.isSaving,
      lastCommittedId:
          clearCommitted ? null : (lastCommittedId ?? this.lastCommittedId),
      unavailableItemLabel:
          clearError ? null : (unavailableItemLabel ?? this.unavailableItemLabel),
    );
  }

  @override
  List<Object?> get props => <Object?>[
        status,
        deals,
        selectedDeal,
        query,
        errorMessage,
        isSaving,
        lastCommittedId,
        unavailableItemLabel,
      ];
}
