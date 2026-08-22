import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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

  test('saveToken rejects wrong length without saving', () async {
    SharedPreferences.setMockInitialValues({});
    final s = DashboardState(fetch: (u, h, t) async => _json([]));
    expect(await s.saveToken('short'), isFalse);
    expect(s.token, isNull);
    expect(await s.saveToken('psk_73928b0b75931018721fcbbbd4deda5b'), isTrue);
    expect(s.token, isNotNull);
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
}
