import 'package:flutter/foundation.dart';

/// Counts in-flight network requests (Supabase Auth/REST — every GET, POST,
/// PATCH, PUT, DELETE) so the UI can show a loading indicator for the whole
/// duration of any request, regardless of which screen triggered it.
class NetworkActivityProvider extends ChangeNotifier {
  int _activeRequests = 0;

  bool get isBusy => _activeRequests > 0;

  void requestStarted() {
    _activeRequests++;
    if (_activeRequests == 1) notifyListeners();
  }

  void requestFinished() {
    _activeRequests = _activeRequests > 0 ? _activeRequests - 1 : 0;
    if (_activeRequests == 0) notifyListeners();
  }
}
