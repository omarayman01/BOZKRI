import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../model/client_model.dart';
import '../../errors/failure.dart';
import '../../provider/clients_cache_provider.dart';
import '../../repos/clients_repo.dart';
import 'clients_state.dart';

/// Owns client list CRUD. Every successful read or write is mirrored into
/// [ClientsCacheProvider] so the rest of the app sees it immediately.
class ClientsCubit extends Cubit<ClientsState> {
  ClientsCubit(this._repo) : super(const ClientsState());

  final ClientsRepo _repo;

  Future<void> load(ClientsCacheProvider cache, {bool activeOnly = false}) async {
    emit(state.copyWith(status: ClientsStatus.loading, clearError: true));
    try {
      final List<ClientModel> clients =
          await _repo.getClients(activeOnly: activeOnly);
      cache.setClients(clients);
      emit(state.copyWith(status: ClientsStatus.success, clients: clients));
    } on Failure catch (failure) {
      emit(state.copyWith(
        status: ClientsStatus.failure,
        errorMessage: failure.message,
      ));
    }
  }

  void search(String query) => emit(state.copyWith(query: query));

  Future<bool> addClient(
    ClientsCacheProvider cache, {
    required String name,
    String? phone,
    String? notes,
    bool isActive = true,
    String? passportId,
    String? nationalId,
  }) async {
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      final int id = await _repo.addClient(
        name: name,
        phone: phone,
        notes: notes,
        isActive: isActive,
        passportId: passportId,
        nationalId: nationalId,
      );
      final ClientModel? created = await _repo.getClient(id);
      if (created != null) {
        cache.upsert(created);
        final List<ClientModel> updated = <ClientModel>[...state.clients, created]
          ..sort((ClientModel a, ClientModel b) => a.name.compareTo(b.name));
        emit(state.copyWith(
          clients: updated,
          status: ClientsStatus.success,
          isSaving: false,
        ));
      } else {
        emit(state.copyWith(isSaving: false));
      }
      return true;
    } on Failure catch (failure) {
      emit(state.copyWith(isSaving: false, errorMessage: failure.message));
      return false;
    }
  }

  Future<bool> updateClient(
      ClientsCacheProvider cache, ClientModel client) async {
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      await _repo.updateClient(client);
      cache.upsert(client);
      final List<ClientModel> updated = state.clients
          .map((ClientModel c) => c.id == client.id ? client : c)
          .toList();
      emit(state.copyWith(
        clients: updated,
        status: ClientsStatus.success,
        isSaving: false,
      ));
      return true;
    } on Failure catch (failure) {
      emit(state.copyWith(isSaving: false, errorMessage: failure.message));
      return false;
    }
  }

  Future<bool> deleteClient(ClientsCacheProvider cache, int id) async {
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      await _repo.deleteClient(id);
      cache.remove(id);
      emit(state.copyWith(
        clients: state.clients.where((ClientModel c) => c.id != id).toList(),
        status: ClientsStatus.success,
        isSaving: false,
      ));
      return true;
    } on Failure catch (failure) {
      emit(state.copyWith(isSaving: false, errorMessage: failure.message));
      return false;
    }
  }

  void clearError() => emit(state.copyWith(clearError: true));
}
