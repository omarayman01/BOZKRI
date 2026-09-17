import 'package:flutter/foundation.dart';

import '../../model/client_model.dart';

/// Shared in-memory client list. Cubits write here after a successful load or
/// mutation; screens read from here so a client added in one place is visible
/// everywhere immediately.
class ClientsCacheProvider extends ChangeNotifier {
  List<ClientModel> _clients = <ClientModel>[];

  List<ClientModel> get clients => List<ClientModel>.unmodifiable(_clients);

  List<ClientModel> get activeClients =>
      _clients.where((ClientModel c) => c.isActive).toList();

  bool get isEmpty => _clients.isEmpty;

  ClientModel? byId(int id) {
    for (final ClientModel c in _clients) {
      if (c.id == id) return c;
    }
    return null;
  }

  String nameOf(int id) => byId(id)?.name ?? '';

  List<ClientModel> search(String query) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) return activeClients;
    return _clients
        .where((ClientModel c) =>
            c.name.toLowerCase().contains(q) ||
            (c.phone ?? '').toLowerCase().contains(q))
        .toList();
  }

  void setClients(List<ClientModel> clients) {
    _clients = List<ClientModel>.from(clients);
    notifyListeners();
  }

  void upsert(ClientModel client) {
    final int index =
        _clients.indexWhere((ClientModel c) => c.id == client.id);
    if (index >= 0) {
      _clients[index] = client;
    } else {
      _clients.add(client);
    }
    _clients.sort((ClientModel a, ClientModel b) => a.name.compareTo(b.name));
    notifyListeners();
  }

  void remove(int id) {
    _clients.removeWhere((ClientModel c) => c.id == id);
    notifyListeners();
  }

  void clear() {
    _clients = <ClientModel>[];
    notifyListeners();
  }
}
