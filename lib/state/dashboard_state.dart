import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:amber/api_cache.dart';
import 'package:amber/bar_chart.dart' show meterInterval;
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

  Timer? _forecastTimer, _usageTimer;
  int _gen = 0; // bumped on site switch / token change; stale awaits bail
  bool _isDisposed = false;

  int get intervalLength => selectedSite?.intervalLength ?? meterInterval;
  Map<String, String> get _headers =>
      {'accept': 'application/json', 'Authorization': 'Bearer $token'};

  Future<void> init() async {
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
    _forecastTimer = Timer.periodic(
        const Duration(minutes: 1), (_) => refreshForecast());
    _usageTimer =
        Timer.periodic(const Duration(hours: 1), (_) => refreshUsage());
    notifyListeners();
  }

  Future<bool> saveToken(String v) async {
    if (v.length != 36) return false;
    final prefs = await SharedPreferences.getInstance();
    if (_isDisposed) return true;
    await prefs.setString('amberToken', v);
    if (_isDisposed) return true;
    token = v;
    _gen++;
    ApiCache.instance.clear();
    await loadSites();
    if (_isDisposed) return true;
    unawaited(refreshForecast());
    unawaited(refreshUsage());
    notifyListeners();
    return true;
  }

  Future<void> loadSites() async {
    final r = await _fetch(Uri.parse('$_base/sites'), _headers, Duration.zero);
    if (_isDisposed) return;
    if (r.statusCode != 200) {
      lastError = 'Could not load your sites (HTTP ${r.statusCode}). '
          'Check your API token in Settings.';
      notifyListeners();
      return;
    }
    sites = (jsonDecode(r.body) as List).map((j) => Site.fromJson(j)).toList();
    if (sites.isNotEmpty) {
      selectedSite = sites.lastWhere((s) => s.status != 'closed',
          orElse: () => sites.last);
    }
    lastError = null;
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
    notifyListeners();
  }

  Future<void> refreshUsage() async {
    final site = selectedSite;
    if (token == null || site == null) return;
    final gen = _gen;
    final fmt = DateFormat('yyyy-MM-dd');
    for (int period = 0; period <= 3; period++) {
      final start = fmt.format(DateTime.now().subtract(Duration(days: period * 7 + 7)));
      final end = fmt.format(DateTime.now().subtract(Duration(days: period * 7 + 1)));
      final uri = Uri.parse(
          '$_base/sites/${site.id}/usage?startDate=$start&endDate=$end');
      final r = await _fetch(uri, _headers, const Duration(hours: 1));
      if (gen != _gen || _isDisposed) return;
      if (r.statusCode != 200) {
        lastError = 'Could not load usage history (HTTP ${r.statusCode}).';
        notifyListeners();
        return;
      }
      weekData[period] =
          (jsonDecode(r.body) as List).map((j) => Usage.fromJson(j)).toList(growable: false);
      notifyListeners();
    }
    // today (may legitimately be empty — usage often lags a day)
    final today = fmt.format(DateTime.now());
    final r = await _fetch(
        Uri.parse('$_base/sites/${site.id}/usage?startDate=$today&endDate=$today'),
        _headers, const Duration(minutes: 30));
    if (gen != _gen || _isDisposed) return;
    todayUsage = r.statusCode == 200
        ? (jsonDecode(r.body) as List).map((j) => Usage.fromJson(j)).toList()
        : null;
    notifyListeners();
  }

  @override
  void dispose() {
    _forecastTimer?.cancel();
    _usageTimer?.cancel();
    _isDisposed = true;
    super.dispose();
  }
}
