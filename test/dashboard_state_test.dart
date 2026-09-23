import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:amber/model/Usage.dart';
import 'package:amber/bar_chart.dart' show daily;
import 'package:amber/state/dashboard_state.dart';

http.Response _json(Object body) => http.Response(jsonEncode(body), 200);

const _sites = [
  {"id": "old", "nmi": "1", "network": "Evoenergy", "status": "closed", "intervalLength": 5,
    "channels": [], "activeFrom": "2020-01-01"},
  {"id": "new", "nmi": "2", "network": "Evoenergy", "status": "active", "intervalLength": 5,
    "channels": [], "activeFrom": "2024-01-01"},
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('connect() rejects the wrong length without fetching', () async {
    var fetched = false;
    final s = DashboardState(fetch: (u, h, t) async {
      fetched = true;
      return _json([]);
    });
    final error = await s.connect('short');
    expect(error, 'Amber tokens are 36 characters — check you copied all of it.');
    expect(fetched, isFalse);
    expect(s.token, isNull);
    s.dispose();
  });

  test('connect() success installs sites/selected site, persists the token, and clears lastError',
      () async {
    SharedPreferences.setMockInitialValues({});
    final s = DashboardState(fetch: (u, h, t) async => _json(_sites));
    final error = await s.connect('c' * 36);
    expect(error, isNull);
    expect(s.token, 'c' * 36);
    expect(s.sites.length, 2);
    expect(s.selectedSite!.id, 'new'); // last non-closed, matching loadSites
    expect(s.lastError, isNull);
    expect(s.tokenRejected, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('amberToken'), 'c' * 36);
    s.dispose();
  });

  test('connect() with a 401 returns the rejected message and leaves a connected account untouched',
      () async {
    SharedPreferences.setMockInitialValues({'amberToken': 'a' * 36});
    final s = DashboardState(fetch: (u, h, t) async {
      if (h['Authorization'] == 'Bearer ${'a' * 36}') return _json(_sites);
      return http.Response('nope', 401);
    });
    await s.init();
    expect(s.token, 'a' * 36);
    expect(s.sites.length, 2);

    final error = await s.connect('b' * 36);
    expect(error,
        "Amber didn't accept that token. Generate a new one and paste it again.");
    // Nothing changed: still the old token/sites, and the pref wasn't touched.
    expect(s.token, 'a' * 36);
    expect(s.sites.length, 2);
    expect(s.selectedSite!.id, 'new');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('amberToken'), 'a' * 36);
    s.dispose();
  });

  test('connect() with an empty site list says so and changes nothing', () async {
    SharedPreferences.setMockInitialValues({});
    final s = DashboardState(fetch: (u, h, t) async => _json([]));
    final error = await s.connect('c' * 36);
    expect(error, 'That token works, but there are no sites on this Amber account.');
    expect(s.token, isNull);
    s.dispose();
  });

  test('connect() offline returns the offline message and changes nothing', () async {
    final s =
        DashboardState(fetch: (u, h, t) async => throw const SocketException('offline'));
    final error = await s.connect('c' * 36);
    expect(error, DashboardState.offlineMessage);
    expect(s.token, isNull);
    s.dispose();
  });

  test('a connect still checking when the token is removed does not install it', () async {
    // The generation guard every fetcher carries: the late /sites answer
    // belongs to a token the user has since walked away from.
    SharedPreferences.setMockInitialValues({});
    final gate = Completer<http.Response>();
    final s = DashboardState(fetch: (u, h, t) => gate.future);

    final pending = s.connect('c' * 36);
    await s.removeToken();
    gate.complete(_json(_sites));

    expect(await pending, isNotNull);
    expect(s.token, isNull);
    expect(s.sites, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('amberToken'), isNull);
    s.dispose();
  });

  test('loadSites sets tokenRejected on a 401 and clears it on a later success', () async {
    SharedPreferences.setMockInitialValues({'amberToken': 'a' * 36});
    var reject = true;
    final s = DashboardState(fetch: (u, h, t) async {
      if (reject) return http.Response('nope', 401);
      return _json(_sites);
    });
    s.token = 'a' * 36;
    await s.loadSites();
    expect(s.tokenRejected, isTrue);
    expect(s.lastError,
        'Amber no longer accepts your saved token. Generate a new one and connect again.');

    reject = false;
    await s.loadSites();
    expect(s.tokenRejected, isFalse);
    expect(s.lastError, isNull);
    s.dispose();
  });

  test('removeToken clears the token, sites, and the saved pref', () async {
    SharedPreferences.setMockInitialValues({'amberToken': 'a' * 36});
    final s = DashboardState(fetch: (u, h, t) async => _json(_sites));
    await s.init();
    expect(s.token, isNotNull);
    expect(s.sites, isNotEmpty);

    await s.removeToken();
    expect(s.token, isNull);
    expect(s.sites, isEmpty);
    expect(s.selectedSite, isNull);
    expect(s.forecastData, isNull);
    expect(s.todayUsage, isNull);
    expect(s.tokenRejected, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('amberToken'), isNull);
    s.dispose();
  });

  test('loadSites prefers last active site and keeps closed ones listed', () async {
    SharedPreferences.setMockInitialValues({'amberToken': 'x' * 36});
    final urls = <String>[];
    final s = DashboardState(fetch: (u, h, t) async {
      urls.add(u.path);
      if (u.path.endsWith('/sites')) return _json(_sites);
      return _json([]);
    });
    await s.init();
    expect(s.sites.length, 2);
    expect(s.selectedSite!.id, 'new');
    s.dispose();
  });

  test('stale responses after site switch are discarded', () async {
    SharedPreferences.setMockInitialValues({'amberToken': 'x' * 36});
    final s = DashboardState(fetch: (u, h, t) async {
      if (u.path.endsWith('/sites')) return _json(_sites);
      if (u.path.contains('/sites/old/')) {
        await Future.delayed(const Duration(milliseconds: 50));
        return _json([{"type": "ActualInterval", "duration": 5, "date": "2026-08-21",
          "nemTime": "2026-08-21T00:05:00+10:00", "kwh": 9.9, "channelType": "general",
          "channelIdentifier": "E1"}]);
      }
      return _json([]);
    });
    await s.init();
    s.selectSite(s.sites.first);            // 'old' — slow responses
    s.selectSite(s.sites.last);             // 'new' — instant empties
    await Future.delayed(const Duration(milliseconds: 100));
    // the slow 'old' data must NOT have landed in weekData
    expect(s.weekData.every((w) => w == null || w.isEmpty), isTrue);
    s.dispose();
  });

  test('dispose during init does not throw or leak timers', () async {
    SharedPreferences.setMockInitialValues({'amberToken': 'x' * 36});
    final sitesCompleter = Completer<http.Response>();
    var initCompleted = false;
    final s = DashboardState(fetch: (u, h, t) async {
      if (u.path.endsWith('/sites')) return sitesCompleter.future;
      return _json([]);
    });
    // Start init but don't await it yet
    final initFuture = s.init().then((_) { initCompleted = true; });
    // Give it time to reach the sites fetch
    await Future.delayed(const Duration(milliseconds: 10));
    // Dispose before sites response arrives
    s.dispose();
    // Complete the sites fetch
    sitesCompleter.complete(_json(_sites));
    // Wait for init to finish — should not throw despite dispose
    // This verifies that dispose() mid-await doesn't cause ChangeNotifier errors
    await initFuture;
    expect(initCompleted, isTrue);
  });

  test('offline first launch: init survives, warns, and keeps polling',
      () async {
    SharedPreferences.setMockInitialValues({'amberToken': 'x' * 36});
    var online = false;
    final s = DashboardState(fetch: (u, h, t) async {
      if (!online) throw const SocketException('Failed host lookup');
      if (u.path.endsWith('/sites')) return _json(_sites);
      return _json([]);
    });

    // Must not throw even though every fetch does.
    await s.init();
    expect(s.lastError, DashboardState.offlineMessage);
    expect(s.sites, isEmpty);

    // The polling timers were started BEFORE the first await, so recovery
    // doesn't need an app restart: the same instance can fetch again.
    online = true;
    await s.loadSites();
    expect(s.lastError, isNull);
    expect(s.selectedSite!.id, 'new');
    await s.refreshForecast();
    expect(s.lastError, isNull);
    s.dispose();
  });

  test('a throwing refresh does not escape as an unhandled async error',
      () async {
    SharedPreferences.setMockInitialValues({'amberToken': 'x' * 36});
    var fail = false;
    final s = DashboardState(fetch: (u, h, t) async {
      if (fail) throw const SocketException('offline');
      if (u.path.endsWith('/sites')) return _json(_sites);
      return _json([]);
    });
    await s.init();
    fail = true;
    await s.refreshForecast();
    expect(s.lastError, DashboardState.offlineMessage);
    await s.refreshUsage();
    expect(s.lastError, DashboardState.offlineMessage);
    s.dispose();
  });

  test('an account with no sites gets a friendly message', () async {
    SharedPreferences.setMockInitialValues({'amberToken': 'x' * 36});
    final s = DashboardState(fetch: (u, h, t) async => _json([]));
    await s.init();
    expect(s.lastError, 'No sites found on this account.');
    expect(s.selectedSite, isNull);
    s.dispose();
  });

  test('now-summary getters', () {
    final s = DashboardState(fetch: (u, h, t) async => _json([]));
    s.forecastData = [
      Usage(type: 'ActualInterval', perKwh: 30.0, channelType: 'general',
          nemTime: '2026-08-22T09:30:00+10:00', duration: 30),
      Usage(type: 'CurrentInterval', perKwh: 18.4, channelType: 'general',
          nemTime: '2026-08-22T10:00:00+10:00', duration: 30,
          descriptor: 'low', spikeStatus: 'none'),
    ];
    expect(s.currentPriceCents, closeTo(18.4, 0.001));
    expect(s.currentPeriodLabel, 'Off-peak');
    expect(s.isSpike, isFalse);
    s.todayUsage = [
      Usage(type: 'ActualInterval', cost: 120.0, kwh: 1.0, channelType: 'general',
          nemTime: '2026-08-22T00:30:00+10:00', duration: 30, date: '2026-08-22'),
      Usage(type: 'ActualInterval', cost: -30.0, kwh: 1.0, channelType: 'feedIn',
          nemTime: '2026-08-22T00:30:00+10:00', duration: 30, date: '2026-08-22'),
    ];
    // (120 - 30) cents -> $0.90, plus the supply charge prorated by the one
    // general interval present (1 of 48 half-hour slots).
    expect(s.todayCostSoFar, closeTo(0.90 + daily * (1 / 48), 0.001));
  });

  test('one failing week does not abort the rest of the usage cycle', () async {
    SharedPreferences.setMockInitialValues({});
    var usageCalls = 0;
    final s = DashboardState(fetch: (u, h, t) async {
      if (u.path.endsWith('/sites')) return _json(_sites);
      usageCalls++;
      if (usageCalls == 1) return http.Response('rate limited', 429);
      return _json([]);
    });
    s.token = 'x' * 36;
    await s.loadSites();
    await s.refreshUsage();
    expect(s.weekData[0], isNull);          // the failed week stays empty
    expect(s.weekData[1], isNotNull);       // ...but the rest loaded
    expect(s.weekData[3], isNotNull);
    expect(s.todayUsage, isNotNull);        // today still fetched
    expect(s.lastError, contains('429'));   // and the failure is surfaced
    s.dispose();
  });
}
