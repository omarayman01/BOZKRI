import 'package:http/http.dart' as http;

import '../provider/network_activity_provider.dart';

/// Wraps the real HTTP client Supabase uses so every request it makes — every
/// GET/POST/PATCH/PUT/DELETE against Auth or the REST API — is counted while
/// in flight, driving the app-wide loading indicator. Not a caching or
/// retrying layer; it only observes.
class TrackingHttpClient extends http.BaseClient {
  TrackingHttpClient(this._activity) : _inner = http.Client();

  final http.Client _inner;
  final NetworkActivityProvider _activity;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    _activity.requestStarted();
    try {
      return await _inner.send(request);
    } finally {
      _activity.requestFinished();
    }
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
