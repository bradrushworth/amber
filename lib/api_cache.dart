import 'package:http/http.dart' as http;

/// In-memory cache and rate-limit guard for the Amber API.
///
/// The dashboard used to call the Amber `prices/current` endpoint every minute
/// (and re-fetched all four historical weeks on every site switch), which
/// tripped Amber's "too many requests" limit and spammed the user with error
/// snackbars. This layer keeps the dashboard responsive while backing off the
/// server:
///
///  * It serves a cached successful response for the lifetime of [ttl], so the
///    network is only hit when the data could actually have changed (use the
///    data's natural cadence, e.g. the meter interval).
///  * It de-duplicates concurrent identical requests (e.g. the 1-minute timer
///    and a site switch firing together), so they share one network call.
///  * On a failed or rate-limited call it serves the last good response (stale
///    while error) so the chart keeps rendering instead of blanking out.
///  * After a failure it backs off for [errorTtl] before retrying, so a
///    rate-limited key is not hammered once a minute.
class ApiCache {
  ApiCache._();

  static final ApiCache instance = ApiCache._();

  final Map<String, _Entry> _success = {};
  final Map<String, _Entry> _error = {};
  final Map<String, Future<http.Response>> _inflight = {};

  /// Fetch [uri], honoring the cache and any active back-off.
  ///
  /// [ttl] is how long a successful response is served without touching the
  /// network. [errorTtl] is the back-off window applied after a failed call
  /// before the network is retried for that URL. [client] lets tests inject a
  /// mock client; production callers omit it and use the default.
  Future<http.Response> get(Uri uri,
      {Map<String, String>? headers,
      Duration ttl = const Duration(minutes: 1),
      Duration errorTtl = const Duration(seconds: 60),
      http.Client? client}) {
    final key = uri.toString();
    final good = _success[key];

    // 1. A fresh successful response: skip the network entirely.
    if (good != null && good.isFresh(ttl)) {
      return Future.value(good.response);
    }

    // 2. A recent failure: back off and serve whatever we already have.
    final bad = _error[key];
    if (bad != null && bad.isFresh(errorTtl)) {
      if (good != null) return Future.value(good.response);
      return Future.value(bad.response);
    }

    // 3. Reuse an in-flight request for the same key instead of duplicating.
    final pending = _inflight[key];
    if (pending != null) return pending;

    final future = _fetch(uri, headers, key, good, client);
    _inflight[key] = future;
    future.whenComplete(() => _inflight.remove(key));
    return future;
  }

  Future<http.Response> _fetch(Uri uri, Map<String, String>? headers, String key,
      _Entry? good, http.Client? client) async {
    final c = client ?? http.Client();
    http.Response response;
    try {
      response = await c.get(uri, headers: headers);
    } on Exception catch (_) {
      // Network-level failure: keep showing the last good data if we have it.
      if (good != null) return good.response;
      rethrow;
    }

    if (response.statusCode == 200) {
      _success[key] = _Entry(response, DateTime.now());
      _error.remove(key);
    } else {
      _error[key] = _Entry(response, DateTime.now());
      // Prefer the last good data over blanking the chart with an error.
      if (good != null) return good.response;
    }
    return response;
  }

  /// Drop all cached responses (e.g. when the API token is changed).
  void clear() {
    _success.clear();
    _error.clear();
    _inflight.clear();
  }
}

class _Entry {
  _Entry(this.response, this.fetchedAt);

  final http.Response response;
  final DateTime fetchedAt;

  bool isFresh(Duration ttl) => DateTime.now().difference(fetchedAt) < ttl;
}