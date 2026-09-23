import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:amber/api_cache.dart';
import 'package:amber/bar_chart.dart' show meterInterval, daily;
import 'package:amber/model/Sites.dart';
import 'package:amber/model/Usage.dart';
import 'package:amber/periods.dart';

typedef Fetch = Future<http.Response> Function(
    Uri uri, Map<String, String> headers, Duration ttl);

Future<http.Response> _apiCacheFetch(
        Uri uri, Map<String, String> headers, Duration ttl) =>
    ApiCache.instance.get(uri, headers: headers, ttl: ttl);

class DashboardState extends ChangeNotifier {
  DashboardState({Fetch? fetch}) : _fetch = fetch ?? _apiCacheFetch;

  final Fetch _fetch;
  static const _base = 'https://api.amber.com.au/v1';

  String? token;
  List<Site> sites = [];
  Site? selectedSite;
  List<Usage>? forecastData;
  final List<List<Usage>?> weekData = [null, null, null, null];
  List<Usage>? todayUsage;
  String? lastError;

  /// True once a SAVED token has been rejected by Amber (401/403 from
  /// `loadSites`). Distinct from a `connect()` failure (which never saves a
  /// bad token in the first place): this is what routes [HomeShell] back to
  /// the onboarding guide for an account that used to work.
  bool tokenRejected = false;

  Timer? _forecastTimer, _usageTimer;
  int _gen = 0; // bumped on site switch / token change; stale awaits bail
  bool _isDisposed = false;

  int get intervalLength => selectedSite?.intervalLength ?? meterInterval;
  Map<String, String> get _headers =>
      {'accept': 'application/json', 'Authorization': 'Bearer $token'};

  /// Shown for any transport-level failure (no network, DNS, TLS, timeout) or
  /// an unparseable body. Deliberately blame-free and actionable.
  static const offlineMessage = "Can't reach Amber — check your connection.";

  Future<void> init() async {
    // Timers FIRST, before any await. If the very first launch is offline the
    // fetches below fail, and starting the timers afterwards meant the app
    // never polled again — it sat on an empty screen until a manual restart.
    // Both fetchers no-op while token/site are null, so starting early is safe.
    _forecastTimer = Timer.periodic(
        const Duration(minutes: 1), (_) => refreshForecast());
    _usageTimer =
        Timer.periodic(const Duration(hours: 1), (_) => refreshUsage());

    final prefs = await SharedPreferences.getInstance();
    if (_isDisposed) return;
    token = prefs.getString('amberToken');
    if (token != null) {
      await loadSites();
      if (_isDisposed) return;
      unawaited(refreshForecast());
      unawaited(refreshUsage());
    }
    if (_isDisposed) return;
    notifyListeners();
  }

  /// Validates [raw] against the live Amber API and, only on success, adopts
  /// it as the saved token. Returns null on success, else a short human
  /// error message.
  ///
  /// The candidate token is never saved or installed until Amber has
  /// actually accepted it: the old `saveToken` persisted first and found out
  /// second, so a rejected token flipped the whole app to an empty state with
  /// only a dismissible banner and no way back. Every failure path here
  /// leaves the current token, sites, data and prefs completely untouched.
  Future<String?> connect(String raw) async {
    final v = raw.trim();
    if (v.length != 36) {
      return 'Amber tokens are 36 characters — check you copied all of it.';
    }

    final candidateHeaders = {
      'accept': 'application/json',
      'Authorization': 'Bearer $v',
    };
    // Generation-guarded like every fetcher: if the token is removed (or
    // another connect lands) while this check is in flight, its late answer
    // must not install a token the user has since walked away from.
    final gen = _gen;
    http.Response r;
    try {
      r = await _fetch(
          Uri.parse('$_base/sites'), candidateHeaders, Duration.zero);
    } catch (_) {
      return offlineMessage;
    }
    if (_isDisposed || gen != _gen) {
      return 'Your Amber account changed while checking that token. Try again.';
    }

    if (r.statusCode == 401 || r.statusCode == 403) {
      return "Amber didn't accept that token. Generate a new one and paste it again.";
    }
    if (r.statusCode != 200) {
      return 'Amber returned an error (HTTP ${r.statusCode}). Try again in a minute.';
    }

    List<Site> candidateSites;
    try {
      candidateSites =
          (jsonDecode(r.body) as List).map((j) => Site.fromJson(j)).toList();
    } catch (_) {
      return offlineMessage;
    }
    if (candidateSites.isEmpty) {
      return 'That token works, but there are no sites on this Amber account.';
    }

    // Amber accepted it: install it. Bump the generation and clear the
    // previous account's data BEFORE any further await, same as the old
    // saveToken — a token change means everything on screen may belong to
    // another account, and in-flight responses for it must be discarded.
    _gen++;
    token = v;
    forecastData = null;
    todayUsage = null;
    for (var i = 0; i < 4; i++) {
      weekData[i] = null;
    }
    // Install from the response already in hand rather than fetching /sites
    // again; same selection rule as loadSites (last non-closed, else last).
    sites = candidateSites;
    selectedSite = sites.lastWhere((s) => s.status != 'closed',
        orElse: () => sites.last);
    lastError = null;
    tokenRejected = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (_isDisposed) return null;
    await prefs.setString('amberToken', v);
    if (_isDisposed) return null;
    ApiCache.instance.clear();
    unawaited(refreshForecast());
    unawaited(refreshUsage());
    notifyListeners();
    return null;
  }

  /// Forgets the saved token entirely, sending the user back to the
  /// onboarding guide. The Amber account itself is unaffected.
  Future<void> removeToken() async {
    _gen++;
    token = null;
    sites = [];
    selectedSite = null;
    forecastData = null;
    todayUsage = null;
    for (var i = 0; i < 4; i++) {
      weekData[i] = null;
    }
    lastError = null;
    tokenRejected = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (_isDisposed) return;
    await prefs.remove('amberToken');
    if (_isDisposed) return;
    ApiCache.instance.clear();
    notifyListeners();
  }

  Future<void> loadSites() async {
    // Guard like the other fetchers: two overlapping loads must not let the
    // earlier /sites response land last and install the wrong account.
    final gen = _gen;
    try {
      final r = await _fetch(Uri.parse('$_base/sites'), _headers, Duration.zero);
      if (gen != _gen || _isDisposed) return;
      if (r.statusCode != 200) {
        if (r.statusCode == 401 || r.statusCode == 403) {
          // The token that WAS accepted no longer is (revoked/regenerated
          // elsewhere) — different from connect() rejecting a candidate that
          // was never saved. Routes HomeShell back to the guide.
          tokenRejected = true;
          lastError =
              'Amber no longer accepts your saved token. Generate a new one and connect again.';
        } else {
          lastError = 'Could not load your sites (HTTP ${r.statusCode}). '
              'Check your API token in Settings.';
        }
        notifyListeners();
        return;
      }
      sites = (jsonDecode(r.body) as List).map((j) => Site.fromJson(j)).toList();
      if (sites.isEmpty) {
        lastError = 'No sites found on this account.';
        notifyListeners();
        return;
      }
      selectedSite = sites.lastWhere((s) => s.status != 'closed',
          orElse: () => sites.last);
      lastError = null;
      tokenRejected = false;
    } catch (_) {
      // Offline / DNS / TLS / malformed body. Never let this escape: init()
      // awaits it, and an unhandled exception there used to abort the rest of
      // start-up (leaving the app blank with no way to retry).
      if (gen != _gen || _isDisposed) return;
      lastError = offlineMessage;
    }
    if (gen != _gen || _isDisposed) return;
    notifyListeners();
  }

  void selectSite(Site s) {
    selectedSite = s;
    _gen++;
    forecastData = null;
    todayUsage = null;
    for (var i = 0; i < 4; i++) {
      weekData[i] = null;
    }
    notifyListeners();
    unawaited(refreshForecast());
    unawaited(refreshUsage());
  }

  Future<void> refreshForecast() async {
    final site = selectedSite;
    if (token == null || site == null) return;
    final gen = _gen;
    final il = site.intervalLength ?? meterInterval;
    try {
      final (back, fwd) = computePeriods(DateTime.now(), il);
      final uri = Uri.parse(
          '$_base/sites/${site.id}/prices/current?next=$fwd&previous=$back&resolution=$il');
      final r = await _fetch(uri, _headers, Duration(minutes: il));
      if (gen != _gen || _isDisposed) return;
      if (r.statusCode != 200) {
        lastError = 'Could not load prices (HTTP ${r.statusCode}).';
      } else {
        forecastData = (jsonDecode(r.body) as List)
            .map((j) => Usage.fromJson(j))
            .toList()
            .reversed
            .toList();
        lastError = null;
      }
    } catch (_) {
      // A throwing fetch/parse here runs on a timer tick with no one to catch
      // it; swallow it into a friendly banner and let the next tick retry.
      if (gen != _gen || _isDisposed) return;
      lastError = offlineMessage;
    }
    if (gen != _gen || _isDisposed) return;
    notifyListeners();
  }

  Future<void> refreshUsage() async {
    final site = selectedSite;
    if (token == null || site == null) return;
    final gen = _gen;
    final fmt = DateFormat('yyyy-MM-dd');
    // One clock reading for the whole cycle: nine separate DateTime.now()
    // calls could straddle midnight and compute overlapping/gapped windows.
    final now = DateTime.now();
    bool anyFailure = false;
    try {
      for (int period = 0; period <= 3; period++) {
        final start = fmt.format(now.subtract(Duration(days: period * 7 + 7)));
        final end = fmt.format(now.subtract(Duration(days: period * 7 + 1)));
        final uri = Uri.parse(
            '$_base/sites/${site.id}/usage?startDate=$start&endDate=$end');
        final r = await _fetch(uri, _headers, const Duration(hours: 1));
        if (gen != _gen || _isDisposed) return;
        if (r.statusCode != 200) {
          // Record and keep going: one rate-limited week used to blank ALL
          // tabs for the whole hourly cycle. The other weeks and today still
          // load, and ApiCache's 60s error backoff lets a later tick heal it.
          lastError = 'Could not load usage history (HTTP ${r.statusCode}).';
          anyFailure = true;
          notifyListeners();
          continue;
        }
        weekData[period] =
            (jsonDecode(r.body) as List).map((j) => Usage.fromJson(j)).toList(growable: false);
        notifyListeners();
      }
      // today (may legitimately be empty — usage often lags a day)
      final today = fmt.format(now);
      final r = await _fetch(
          Uri.parse('$_base/sites/${site.id}/usage?startDate=$today&endDate=$today'),
          _headers, const Duration(minutes: 30));
      if (gen != _gen || _isDisposed) return;
      todayUsage = r.statusCode == 200
          ? (jsonDecode(r.body) as List).map((j) => Usage.fromJson(j)).toList()
          : null;
      if (!anyFailure) lastError = null;
    } catch (_) {
      // Same story as refreshForecast: this is fired unawaited and from a
      // timer, so a throw here would be an unhandled async error.
      if (gen != _gen || _isDisposed) return;
      lastError = offlineMessage;
    }
    if (gen != _gen || _isDisposed) return;
    notifyListeners();
  }

  Usage? get _currentRecord => forecastData?.cast<Usage?>().firstWhere(
      (u) => u!.type == 'CurrentInterval' && u.channelType == 'general',
      orElse: () => null);

  double? get currentPriceCents => _currentRecord?.perKwh?.toDouble();

  String? get currentPeriodLabel {
    final r = _currentRecord;
    if (r == null) return null;
    final p = r.tariffInformation?.period ?? r.descriptor;
    switch (p) {
      case 'peak': return 'Peak';
      case 'shoulder': return 'Shoulder';
      case 'solarSponge': return 'Solar sponge';
      case 'offPeak': case 'low': case 'veryLow': return 'Off-peak';
      default: return null;
    }
  }

  bool get isSpike => _currentRecord?.spikeStatus == 'spike';

  double? get todayCostSoFar {
    final t = todayUsage;
    if (t == null || t.isEmpty) return null;
    double cents = 0;
    int generalIntervals = 0;
    for (final u in t) {
      cents += u.cost ?? 0;
      if (u.channelType == 'general') generalIntervals++;
    }
    // Include the supply charge, prorated by how much of the day has data,
    // so the hero agrees with every other cost figure in the app (day_math
    // adds daily per day; the charts draw daily/barsPerDay per bar).
    final int barsPerDay = 24 * 60 ~/ intervalLength;
    final double supplyShare =
        daily * (generalIntervals / barsPerDay).clamp(0.0, 1.0);
    return cents / 100.0 + supplyShare;
  }

  @override
  void dispose() {
    _forecastTimer?.cancel();
    _usageTimer?.cancel();
    _isDisposed = true;
    super.dispose();
  }
}
