import 'package:equatable/equatable.dart';

import '../../../model/client_model.dart';

enum ClientsStatus { initial, loading, success, failure }

class ClientsState extends Equatable {
  const ClientsState({
    this.status = ClientsStatus.initial,
    this.clients = const <ClientModel>[],
    this.query = '',
    this.errorMessage,
    this.isSaving = false,
  });

  final ClientsStatus status;
  final List<ClientModel> clients;
  final String query;
  final String? errorMessage;
  final bool isSaving;

  bool get isLoading => status == ClientsStatus.loading;
  bool get isFailure => status == ClientsStatus.failure;
  bool get isEmpty => status == ClientsStatus.success && clients.isEmpty;

  List<ClientModel> get visibleClients {
    if (query.trim().isEmpty) return clients;
    final String q = query.trim().toLowerCase();
    return clients
        .where((ClientModel c) =>
            c.name.toLowerCase().contains(q) ||
            (c.phone ?? '').toLowerCase().contains(q) ||
            (c.passportId ?? '').toLowerCase().contains(q) ||
            (c.nationalId ?? '').toLowerCase().contains(q))
        .toList();
  }

  ClientsState copyWith({
    ClientsStatus? status,
    List<ClientModel>? clients,
    String? query,
    String? errorMessage,
    bool? isSaving,
    bool clearError = false,
  }) {
    return ClientsState(
      status: status ?? this.status,
      clients: clients ?? this.clients,
      query: query ?? this.query,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSaving: isSaving ?? this.isSaving,
    );
  }

  @override
  List<Object?> get props =>
      <Object?>[status, clients, query, errorMessage, isSaving];
}
