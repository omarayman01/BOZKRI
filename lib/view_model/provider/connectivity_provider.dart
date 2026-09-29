import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Whether the device currently has any network path at all. This is a
/// necessary-but-not-sufficient signal for "can reach Supabase" — the sync
/// engine still treats an actual request failure as offline too.
class ConnectivityProvider extends ChangeNotifier {
  ConnectivityProvider() {
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      _setOnline(!results.contains(ConnectivityResult.none));
    });
    Connectivity().checkConnectivity().then(
        (results) => _setOnline(!results.contains(ConnectivityResult.none)));
  }

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  late final StreamSubscription<List<ConnectivityResult>> _sub;

  void _setOnline(bool value) {
    if (value == _isOnline) return;
    _isOnline = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
