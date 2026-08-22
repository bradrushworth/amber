# Amber UI Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Amber's dropdown-driven single screen with the approved tabbed shell (Now / Days / Weeks), hero panel, orientation-adaptive history, and chart hygiene.

**Architecture:** Extract all fetch/state logic from `HomePageState` into a `DashboardState` ChangeNotifier (Provider), build the new tab screens beside the old UI, then swap the root and delete the old screen and dead theme system in one final task. `DataAggregator`, `ApiCache`, and `periods.dart` are reused untouched except where the spec requires new parameters.

**Tech Stack:** Flutter stable, provider 6, shared_preferences, fl_chart 0.69 (pinned — do NOT upgrade), http.

**Spec:** `docs/superpowers/specs/2026-08-22-ui-overhaul-design.md` (read it first; this plan implements its Amber half; Momentum port is a separate future plan).

## Global Constraints

- fl_chart stays pinned at 0.69.x; use only APIs already used in `lib/bar_chart.dart`.
- Chart visual style (colors list, bar widths, rounded caps) is unchanged.
- Token validation stays exactly `length == 36`; failures must show an inline message.
- Dark-only UI; background `Color(0xFF20202A)`, cards `Color(0xFF1A1A26)`.
- Every commit message ends with `[skip ci]` (no version bump in this plan; the owner releases).
- `flutter test` green and `flutter analyze` no NEW warnings after every task.
- All timestamps AEST via existing `Utils.toLocal` — never `DateTime.toLocal()`.
- Windows note: if `flutter test` fails with a locked `build\unit_test_assets`, run `Remove-Item -Recurse -Force build` and retry.

---

### Task 1: DashboardState (state extraction)

**Files:**
- Create: `lib/state/dashboard_state.dart`
- Test: `test/dashboard_state_test.dart`

**Interfaces:**
- Consumes: `ApiCache.instance.get(Uri, {headers, ttl})` (`lib/api_cache.dart`), `Site` (`lib/model/Sites.dart`), `Usage` (`lib/model/Usage.dart`), `computePeriods` (`lib/periods.dart`), `meterInterval` const (`lib/bar_chart.dart`).
- Produces (later tasks depend on these exact members):
  ```dart
  typedef Fetch = Future<http.Response> Function(Uri uri, Map<String, String> headers, Duration ttl);
  class DashboardState extends ChangeNotifier {
    DashboardState({Fetch? fetch});
    String? token;
    List<Site> sites;                 // starts []
    Site? selectedSite;
    List<Usage>? forecastData;        // newest-last, as today
    final List<List<Usage>?> weekData; // length 4; [0] = last 7 days
    List<Usage>? todayUsage;          // today's usage records, may be null/empty
    String? lastError;                // human-readable, null when healthy
    int get intervalLength;           // selectedSite?.intervalLength ?? meterInterval
    Future<void> init();              // load prefs token -> loadSites -> refreshAll; starts timers
    Future<bool> saveToken(String v); // false (no save) unless v.length == 36
    Future<void> loadSites();
    void selectSite(Site s);          // triggers refreshForecast + refreshUsage
    Future<void> refreshForecast();
    Future<void> refreshUsage();      // 4 weeks + today
    @override void dispose();         // cancels timers
  }
  ```

- [ ] **Step 1: Write the failing tests**

```dart
// test/dashboard_state_test.dart
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
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/dashboard_state_test.dart`
Expected: FAIL — `lib/state/dashboard_state.dart` does not exist.

- [ ] **Step 3: Implement DashboardState**

Create `lib/state/dashboard_state.dart`. Port the bodies of `_getSites`, `_getForecast`, `_getHistoricalUsage` from `lib/main.dart:177-320` with these changes: no `BuildContext`/`ScaffoldMessenger`/`setState` — set `lastError` + `notifyListeners()` instead; guard staleness with a generation counter, not `mounted`:

```dart
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

  int get intervalLength => selectedSite?.intervalLength ?? meterInterval;
  Map<String, String> get _headers =>
      {'accept': 'application/json', 'Authorization': 'Bearer $token'};

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('amberToken');
    if (token != null) {
      await loadSites();
      unawaited(refreshForecast());
      unawaited(refreshUsage());
    }
    _forecastTimer = Timer.periodic(
        const Duration(minutes: 1), (_) => refreshForecast());
    _usageTimer =
        Timer.periodic(const Duration(hours: 1), (_) => refreshUsage());
    notifyListeners();
  }

  Future<bool> saveToken(String v) async {
    if (v.length != 36) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('amberToken', v);
    token = v;
    _gen++;
    ApiCache.instance.clear();
    await loadSites();
    unawaited(refreshForecast());
    unawaited(refreshUsage());
    notifyListeners();
    return true;
  }

  Future<void> loadSites() async {
    final r = await _fetch(Uri.parse('$_base/sites'), _headers, Duration.zero);
    if (r.statusCode != 200) {
      lastError = 'Could not load your sites (HTTP ${r.statusCode}). '
          'Check your API token in Settings.';
      notifyListeners();
      return;
    }
    sites = (jsonDecode(r.body) as List).map((j) => Site.fromJson(j)).toList();
    selectedSite = sites.lastWhere((s) => s.status != 'closed',
        orElse: () => sites.isNotEmpty ? sites.last : (throw StateError('no sites')));
    lastError = null;
    notifyListeners();
  }

  void selectSite(Site s) {
    selectedSite = s;
    _gen++;
    forecastData = null;
    todayUsage = null;
    for (var i = 0; i < 4; i++) weekData[i] = null;
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
    if (gen != _gen) return;
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
      if (gen != _gen) return;
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
    if (gen != _gen) return;
    todayUsage = r.statusCode == 200
        ? (jsonDecode(r.body) as List).map((j) => Usage.fromJson(j)).toList()
        : null;
    notifyListeners();
  }

  @override
  void dispose() {
    _forecastTimer?.cancel();
    _usageTimer?.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/dashboard_state_test.dart` — Expected: PASS (3 tests).
Run: `flutter test` — Expected: all existing tests still PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/state/dashboard_state.dart test/dashboard_state_test.dart
git commit -m "feat: extract DashboardState ChangeNotifier from HomePageState [skip ci]"
```

---

### Task 2: Now-summary getters (current price, period, spike, today-so-far)

**Files:**
- Modify: `lib/model/Usage.dart` (add `spikeStatus`)
- Modify: `lib/state/dashboard_state.dart`
- Test: `test/dashboard_state_test.dart` (append)

**Interfaces:**
- Produces on `DashboardState`:
  ```dart
  double? get currentPriceCents;   // general-channel CurrentInterval perKwh
  String? get currentPeriodLabel;  // 'Peak' / 'Shoulder' / 'Off-peak' / 'Solar sponge' / null
  bool get isSpike;                // spikeStatus == 'spike'
  double? get todayCostSoFar;      // dollars; null when todayUsage null/empty
  ```
- Produces on `Usage`: `String? spikeStatus;` parsed from `json['spikeStatus']`.

- [ ] **Step 1: Append failing tests**

```dart
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
    expect(s.todayCostSoFar, closeTo(0.90, 0.001)); // (120 - 30) cents -> $
  });
```

Note: `Usage` has a named constructor with these fields already (see `test/bar_chart_test.dart` usage); add `spikeStatus` to it.

- [ ] **Step 2: Run to verify failure** — `flutter test test/dashboard_state_test.dart` fails: no `spikeStatus`, no getters.

- [ ] **Step 3: Implement**

In `lib/model/Usage.dart`: add `String? spikeStatus;` to fields, named constructor, and `spikeStatus = json['spikeStatus'];` in `fromJson`.

In `DashboardState`:

```dart
  Usage? get _currentRecord => forecastData?.cast<Usage?>().firstWhere(
      (u) => u!.type == 'CurrentInterval' && u.channelType == 'general',
      orElse: () => null);

  double? get currentPriceCents => _currentRecord?.perKwh;

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
    for (final u in t) { cents += u.cost ?? 0; }
    return cents / 100.0;
  }
```

- [ ] **Step 4: Run tests** — `flutter test` all green.

- [ ] **Step 5: Commit**

```bash
git add lib/model/Usage.dart lib/state/dashboard_state.dart test/dashboard_state_test.dart
git commit -m "feat: now-summary getters and Usage.spikeStatus [skip ci]"
```

---

### Task 3: BarChartWidget1 — headerless mode and hygienic axes

**Files:**
- Modify: `lib/bar_chart.dart`
- Test: `test/widget_smoke_test.dart` (create)

**Interfaces:**
- Produces: `BarChartWidget1(data, title, interval, duration, {ending, prices, forecast, feedIn, showHeader = true, yUnit = ''})`. When `showHeader == false` the `TopSectionWidget` row is not built. `yUnit` is appended to y-axis labels (e.g. `'c'`, `'\$'`, `'kWh'` — display only).
- X-axis: labels every 3 hours (`00:00, 03:00 …`), horizontal (angle 0), instead of every-hour rotated.

- [ ] **Step 1: Write failing widget smoke test**

```dart
// test/widget_smoke_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:amber/bar_chart.dart';
import 'package:amber/my_theme_model.dart';
import 'package:amber/model/Usage.dart';

List<Usage> day() => List.generate(48, (i) => Usage(
    type: 'ActualInterval', duration: 30, date: '2023-08-12',
    nemTime: DateTime.utc(2023, 8, 11, 14, 0)
        .add(Duration(minutes: (i + 1) * 30)).toIso8601String(),
    kwh: 1.0, cost: 10.0, perKwh: 20.0,
    channelType: 'general', channelIdentifier: 'E1'));

Widget host(Widget child) => ChangeNotifierProvider(
    create: (_) => MyThemeModel(),
    child: MaterialApp(home: Scaffold(body: SizedBox(height: 300, child: child))));

void main() {
  testWidgets('showHeader:false renders no TopSection legend', (t) async {
    await t.pumpWidget(host(BarChartWidget1(
        day(), 'Thu 21 Aug', 30, const Duration(days: 1),
        prices: true, showHeader: false, yUnit: '\$')));
    await t.pump();
    expect(find.text('Thu 21 Aug'), findsNothing); // header suppressed
    expect(find.text('Peak'), findsNothing);       // no per-card legend
  });
}
```

- [ ] **Step 2: Run** — `flutter test test/widget_smoke_test.dart` fails: `showHeader` not defined.

- [ ] **Step 3: Implement**

In `lib/bar_chart.dart`:
1. Add to `BarChartWidget1`: `final bool showHeader; final String yUnit;` with defaults `true` / `''`, passed through the constructor and copied into state in `initState` like the other fields.
2. In `BarChartState.build`, wrap the existing `TopSectionWidget(...)` in `if (_showHeader)` (collection-if inside the children list).
3. Bottom titles: replace the current per-hour rotated labels. Existing code computes `interval: (60 ~/ _interval)`; change the `getTitlesWidget` so labels render only when `graphPos % (3 * (60 ~/ _interval)) == 0`, with `angle: 0`, text style unchanged. Delete the `math.radians(-90)` usage; if `vector_math` becomes unused in this file, remove its import.
4. Left titles: append `_yUnit` to the formatted number (`'$formatted$_yUnit'`), and format with `toStringAsFixed(2)` when `maxY < 1` else `toStringAsFixed(1)` — never two identical adjacent labels (this replaces the current 0/2-decimals switch that produced "$2 / $2").

- [ ] **Step 4: Run** — `flutter test` all green (existing aggregation tests don't touch titles).

- [ ] **Step 5: Commit**

```bash
git add lib/bar_chart.dart test/widget_smoke_test.dart
git commit -m "feat: headerless chart mode, 3-hourly horizontal x labels, y units [skip ci]"
```

---

### Task 4: Chart tap tooltips

**Files:**
- Modify: `lib/bar_chart.dart`

**Interfaces:**
- Produces: tapping a bar shows a fl_chart tooltip `"{HH:mm}\n{value}{unit} · {period}"`; tapping empty space dismisses it. No new public API.

- [ ] **Step 1: Implement (no unit test — fl_chart touch is exercised manually; keep the smoke test green)**

In `BarChartState.build`, add to `BarChartData(...)`:

```dart
  barTouchData: BarTouchData(
    enabled: true,
    handleBuiltInTouches: true,
    touchTooltipData: BarTouchTooltipData(
      getTooltipItem: (group, gi, rod, ri) {
        final label = _barChartTitles[group.x] ?? '';
        final unit = _prices || _forecast ? ' \$' : ' kWh';
        return BarTooltipItem(
            '$label\n${rod.toY.toStringAsFixed(_prices || _forecast ? 2 : 3)}$unit',
            const TextStyle(color: Colors.white, fontSize: 11));
      },
    ),
  ),
```

(`_barChartTitles` is the existing `newTitles` map copied in `parseFile`; reuse the field the state already holds.)

- [ ] **Step 2: Verify** — `flutter test` green; run `flutter run -d windows` or web, tap a bar, see tooltip, tap away, it dismisses (fl_chart built-in behaviour).

- [ ] **Step 3: Commit**

```bash
git add lib/bar_chart.dart
git commit -m "feat: informative tap tooltips on chart bars [skip ci]"
```

---

### Task 5: Partial-range aggregation (`allowPartial`)

**Files:**
- Modify: `lib/bar_chart.dart` (`DataAggregator` + `BarChartWidget1`)
- Test: `test/bar_chart_test.dart` (append)

**Interfaces:**
- Produces: `DataAggregator(duration, ending, prices, forecast, feedIn, interval, {nowOverride, allowPartial = false})`. When `allowPartial` is true, missing leading/trailing data renders as empty slots instead of throwing `NotEnoughDataException`. `BarChartWidget1` gains `allowPartial` (default false) and forwards it.

- [ ] **Step 1: Append failing test**

```dart
    test('allowPartial renders a half-empty week instead of throwing', () {
      // 3 days of data, 7-day window
      final data = <Usage>[];
      for (int d = 0; d < 3; d++) {
        for (int i = 0; i < 48; i++) {
          data.add(Usage(duration: 30, date: '2023-08-1${2 + d}',
              nemTime: DateTime.utc(2023, 8, 11 + d, 14, 0)
                  .add(Duration(minutes: (i + 1) * 30)).toIso8601String(),
              kwh: 1.0, channelType: 'general', channelIdentifier: 'E1'));
        }
      }
      final agg = DataAggregator(const Duration(days: 7), const Duration(days: 0),
          false, false, false, 30, allowPartial: true);
      agg.aggregateData(data);                    // must not throw
      expect(agg.newData.length, 48);             // full axis present
      expect(agg.newData[0]!.barRods.first.toY, closeTo(3.0, 0.01)); // 3 days summed
    });
```

- [ ] **Step 2: Run** — fails: `allowPartial` not defined.

- [ ] **Step 3: Implement**

In `DataAggregator`: add `final bool allowPartial;` (constructor named param, default false). Change the range check to:

```dart
    if (!beforeRange || !afterRange) {
      if (!_forecast && !allowPartial) {
        throw NotEnoughDataException();
      }
      for (int graphPos = 0; graphPos < barsPerDay; graphPos++) {
        stackedValues[graphPos] ??= CustomRodGroup();
        newTitles[graphPos] ??= _canonicalHalfHour(graphPos, _interval);
      }
    }
```

In `BarChartWidget1`: add `final bool allowPartial;` (default false), copy to state, pass to the `DataAggregator` constructor in `parseFile`.

- [ ] **Step 4: Run** — `flutter test` all green (existing not-enough-data expectations unchanged since default is false).

- [ ] **Step 5: Commit**

```bash
git add lib/bar_chart.dart test/bar_chart_test.dart
git commit -m "feat: allowPartial aggregation for in-progress weeks [skip ci]"
```

---

### Task 6: LegendBar, ChartCard, and day-total helper

**Files:**
- Create: `lib/widgets/legend_bar.dart`, `lib/widgets/chart_card.dart`, `lib/state/day_math.dart`
- Test: `test/day_math_test.dart`, append to `test/widget_smoke_test.dart`

**Interfaces:**
- `LegendBar({required bool showSupply, required bool showPrices})` — one horizontal wrap of swatch+label pairs using the `colors` list from `bar_chart.dart`: Solar sponge (cyan `colors[0]`? — use the SAME indices the charts use: match each label to the color already used by `CustomRodElement.getCostColor`/legend code in `bar_chart.dart`; copy the mapping, do not invent), Off-peak, Shoulder, Peak, Controlled, Feed-in, plus Supply when `showSupply`.
- `ChartCard({required String title, String? trailing, required Widget chart})` — `Color(0xFF1A1A26)` rounded container; title row (title left, `trailing` right in grey), chart below at fixed height 180.
- `double sumForDay(List<Usage> data, Duration ending, {required bool cost})` in `lib/state/day_math.dart` — sums `cost` (cents→dollars) or `kwh` of general+controlledLoad records for the single AEST day ending `ending` days back from the data's last date (reuse `Utils.toLocal` and the same day-window arithmetic as `DataAggregator.aggregateData`'s `latest`/`earliest`, with `duration = 1 day`). Feed-in cost is ADDED (it is negative in cost terms) for the cost sum and excluded from the kWh sum.

- [ ] **Step 1: Write failing tests**

```dart
// test/day_math_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:amber/state/day_math.dart';
import 'package:amber/model/Usage.dart';

void main() {
  final data = <Usage>[
    Usage(duration: 30, date: '2023-08-12',
        nemTime: '2023-08-12T10:30:00+10:00', kwh: 2.0, cost: 100.0,
        channelType: 'general', channelIdentifier: 'E1'),
    Usage(duration: 30, date: '2023-08-12',
        nemTime: '2023-08-12T10:30:00+10:00', kwh: 1.0, cost: -40.0,
        channelType: 'feedIn', channelIdentifier: 'B1'),
  ];
  test('cost sums general plus negative feed-in, in dollars', () {
    expect(sumForDay(data, const Duration(days: 0), cost: true), closeTo(0.60, 0.001));
  });
  test('kwh sums consumption only', () {
    expect(sumForDay(data, const Duration(days: 0), cost: false), closeTo(2.0, 0.001));
  });
}
```

- [ ] **Step 2: Run** — fails, file missing.

- [ ] **Step 3: Implement the three files** per the interfaces above. `sumForDay` core:

```dart
double sumForDay(List<Usage> data, Duration ending, {required bool cost}) {
  if (data.isEmpty) return 0;
  final latest = Utils.toLocal(DateTime.parse('${data.last.date!}T00:00:00+10:00')
      .subtract(ending).add(const Duration(days: 1)));
  final earliest = latest.subtract(const Duration(days: 1));
  double total = 0;
  for (final u in data) {
    final d = Utils.toLocal(DateTime.parse(u.nemTime!)
        .subtract(Duration(minutes: u.duration ?? 30)));
    if (d.isBefore(earliest) || !d.isBefore(latest)) continue;
    if (cost) {
      total += u.cost ?? 0;
    } else if (u.channelType != 'feedIn') {
      total += u.kwh ?? 0;
    }
  }
  return cost ? total / 100.0 : total;
}
```

Append a smoke test asserting `ChartCard(title: 'Thu 21 Aug', trailing: '\$7.43', chart: SizedBox())` renders both texts.

- [ ] **Step 4: Run** — `flutter test` green.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/legend_bar.dart lib/widgets/chart_card.dart lib/state/day_math.dart test/day_math_test.dart test/widget_smoke_test.dart
git commit -m "feat: LegendBar, ChartCard, day-total helper [skip ci]"
```

---

### Task 7: Now tab and hero panel

**Files:**
- Create: `lib/screens/now_tab.dart`
- Test: `test/now_tab_test.dart`

**Interfaces:**
- `NowTab()` — reads `DashboardState` via `context.watch`. Layout: `LegendBar(showSupply: false, showPrices: true)`; hero container (background `Color(0xFF1A1A26)`): "RIGHT NOW" label, `'{currentPriceCents.toStringAsFixed(1)} c/kWh'` large (or `'—'` when null), sub-line `'{currentPeriodLabel}{isSpike ? " · ⚡ SPIKE" : ""}{todayCostSoFar != null ? " · today so far \$X.XX" : ""}'`; inside the hero a headerless today buy-price chart: `BarChartWidget1(forecastData, 'today', forecastInterval, Duration(days: 1), forecast: true, prices: true, showHeader: false, yUnit: 'c', nowOverride passed as today)` — copy the exact `forecastInterval` cap logic from `lib/main.dart:374-381` (`interval < 30 ? 30 : interval`). Below: `ChartCard`s for "Buy price — yesterday", "Feed-in price — yesterday", "Buy price — tomorrow", "Feed-in price — tomorrow" using the same `BarChartWidget1` flag combinations as the old Forecast tab cards in `lib/main.dart:506-556` (yesterday: `ending: Duration(days: 1)`; feed-in adds `feedIn: true`).

- [ ] **Step 1: Failing widget test** — fake state, assert hero renders price and spike-less sub-line:

```dart
// test/now_tab_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:amber/my_theme_model.dart';
import 'package:amber/screens/now_tab.dart';
import 'package:amber/state/dashboard_state.dart';
import 'package:amber/model/Usage.dart';
import 'package:http/http.dart' as http;

void main() {
  testWidgets('hero shows current price and period', (t) async {
    final s = DashboardState(fetch: (u, h, ttl) async => http.Response('[]', 200));
    s.forecastData = [Usage(type: 'CurrentInterval', perKwh: 18.4,
        channelType: 'general', duration: 30, descriptor: 'low',
        nemTime: DateTime.now().toIso8601String())];
    await t.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<DashboardState>.value(value: s),
      ChangeNotifierProvider(create: (_) => MyThemeModel()),
    ], child: const MaterialApp(home: Scaffold(body: NowTab()))));
    await t.pump();
    expect(find.textContaining('18.4'), findsOneWidget);
    expect(find.textContaining('Off-peak'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run** — fails, screen missing.
- [ ] **Step 3: Implement `NowTab` per the interface.** Guard every chart: render a `ChartCard` with a 180-high grey `Container` placeholder (skeleton) while its data list is null.
- [ ] **Step 4: Run** — green.
- [ ] **Step 5: Commit** — `git add lib/screens/now_tab.dart test/now_tab_test.dart && git commit -m "feat: Now tab with live-price hero [skip ci]"`

---

### Task 8: History tab (Days & Weeks)

**Files:**
- Create: `lib/screens/history_tab.dart`
- Test: `test/history_tab_test.dart`

**Interfaces:**
- `HistoryTab({required bool weeks})` — one widget serves both tabs.
  - Data rows: for Days, 28 entries — day `e` (0 = yesterday) uses `weekData[e ~/ 7]` with `ending: Duration(days: e % 7)`, title `DateFormat('E d MMM').format(now - (e+1) days)`; skip entries whose week slice is still null (render one skeleton card per missing week instead). For Weeks, 4 entries — `weekData[w]`, `duration: 7 days`, `ending: Duration.zero`, title `'Week to {date}'`; plus a leading "This week (partial)" card using `weekData[0]` with `allowPartial: true`.
  - **Portrait** (`MediaQuery.orientation == portrait`): `ChoiceChip` row — Cost / Usage / Prices — then a `ListView` of `ChartCard`s for the chosen metric. Metric→flags: Cost = `prices: true`, `yUnit: '\$'`, trailing `sumForDay(..., cost: true)` as `'\$X.XX'`; Usage = no flags, `yUnit: 'kWh'`, trailing kWh; Prices = `forecast: true, prices: true`, `yUnit: 'c'`, no trailing.
  - **Landscape**: no chips; header row `Text('USAGE (kWh)') | Text('COST (\$)')`; `ListView` of `Row`s, each `Expanded(ChartCard(usage)) + Expanded(ChartCard(cost))` for the same day.
  - Selected chip index is local `StatefulWidget` state, default Cost.

- [ ] **Step 1: Failing tests** — two `testWidgets`: (a) portrait shows the three chips and switching to Usage swaps `yUnit` cards (assert `find.text('Usage')` chip exists and tap works); (b) landscape (set `tester.view.physicalSize = const Size(1600, 720); tester.view.devicePixelRatio = 1;` and reset in teardown) shows the two column headers and no chips. Use a fake `DashboardState` with `weekData[0]` filled from the 48-record generator in `test/widget_smoke_test.dart` (move `day()` into `test/test_data.dart` and import from both).
- [ ] **Step 2: Run** — fails.
- [ ] **Step 3: Implement per interface.**
- [ ] **Step 4: Run** — green.
- [ ] **Step 5: Commit** — `git add lib/screens/history_tab.dart test/history_tab_test.dart test/test_data.dart && git commit -m "feat: history tab with portrait chips and landscape pairs [skip ci]"`

---

### Task 9: Full-screen day/week detail

**Files:**
- Create: `lib/screens/day_detail.dart`
- Modify: `lib/screens/history_tab.dart` (wrap each `ChartCard` in `InkWell` → `Navigator.push`)
- Test: `test/history_tab_test.dart` (append)

**Interfaces:**
- `DayDetail({required String title, required List<Usage> data, required Duration duration, required Duration ending, required int interval})` — Scaffold, app bar titled `title`, body: full-height headerless cost chart (`prices: true, allowPartial: true`), beneath it a totals row of three stat tiles: DAY TOTAL `\$` (`sumForDay(cost: true)`), USED kWh (`sumForDay(cost: false)`), and a third tile FEED-IN `\$` (sum of feed-in `cost` only /100 — add `double sumFeedIn(List<Usage>, Duration ending)` to `lib/state/day_math.dart` with a unit test mirroring Task 6's).

- [ ] **Step 1: Append failing test** — tapping the first portrait card pushes a route whose app bar shows the card's date title.
- [ ] **Step 2: Run** — fails.
- [ ] **Step 3: Implement** (`sumFeedIn` first with its test, then the screen, then the InkWell).
- [ ] **Step 4: Run** — green.
- [ ] **Step 5: Commit** — `git add lib/screens/day_detail.dart lib/state/day_math.dart lib/screens/history_tab.dart test/history_tab_test.dart test/day_math_test.dart && git commit -m "feat: full-screen day detail with totals [skip ci]"`

---

### Task 10: Settings screen (token + About)

**Files:**
- Create: `lib/screens/settings_screen.dart`
- Test: `test/settings_test.dart`

**Interfaces:**
- `SettingsScreen()` — Scaffold with:
  - "Amber API token" `TextFormField` (initial value `state.token ?? ''`, obscured off) + Save button calling `DashboardState.saveToken`; on `false` show inline `Text('Token should be 36 characters', style: TextStyle(color: Colors.redAccent))` below the field (spec: validation KEPT, failure surfaced). On `true` show a `SnackBar('Token saved')`.
  - Instructions line with the two existing links (`app.amber.com.au` "For Developers" / "Generate a new Token") reusing `Utils.launchURI` exactly as `lib/main.dart:422-453` does.
  - "About" section: `ListTile`s for Support (mailto), Improvements (GitHub issues), Source Code (GitHub), Buy Coffee / Visit BitBot (same `kIsWeb && kReleaseMode` switch), copying the URIs verbatim from `lib/main.dart:797-874`.

- [ ] **Step 1: Failing tests** — (a) entering `'short'` and tapping Save shows 'Token should be 36 characters'; (b) entering a 36-char string calls through (assert via fake state's saved token).
- [ ] **Step 2: Run** — fails.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** — green.
- [ ] **Step 5: Commit** — `git add lib/screens/settings_screen.dart test/settings_test.dart && git commit -m "feat: Settings screen with token entry and About [skip ci]"`

---

### Task 11: Onboarding empty state

**Files:**
- Create: `lib/screens/onboarding.dart`
- Test: `test/onboarding_test.dart`

**Interfaces:**
- `Onboarding()` — centered column shown when `token == null`: app name, three numbered steps ("1. Open app.amber.com.au and enable 'For Developers'", "2. Generate a new Token", "3. Paste it in Settings"), a link button opening `app.amber.com.au` via `Utils.launchURI`, and an "Open Settings" `FilledButton` that pushes `SettingsScreen`.

- [ ] **Step 1: Failing test** — renders the three steps and the button; tapping "Open Settings" pushes a route containing the token field.
- [ ] **Step 2: Run** — fails. **Step 3: Implement. Step 4: Run** — green.
- [ ] **Step 5: Commit** — `git add lib/screens/onboarding.dart test/onboarding_test.dart && git commit -m "feat: first-run onboarding [skip ci]"`

---

### Task 12: HomeShell, root swap, old-UI deletion, dark-only theme

**Files:**
- Create: `lib/screens/home_shell.dart`
- Modify: `lib/main.dart` (rewrite to ~80 lines)
- Delete: `lib/my_theme_model.dart`, `lib/top_section.dart`
- Modify: `lib/bar_chart.dart` (remove `Consumer<MyThemeModel>` + `TopSectionWidget` import/usage)
- Test: `test/home_shell_test.dart`; update `test/widget_smoke_test.dart`, `test/now_tab_test.dart` hosts (drop MyThemeModel provider)

**Interfaces:**
- `HomeShell()` — `Scaffold(backgroundColor: Color(0xFF20202A))`; `AppBar`: title column ("Amber" + tappable context line `'{selectedSite.network} · {nmi}'`, `'(closed)'` suffix kept, opening a `showModalBottomSheet` site list that calls `selectSite`), gear `IconButton` → `SettingsScreen`; body: `token == null ? Onboarding() : IndexedStack(index: _tab, children: [NowTab(), HistoryTab(weeks: false), HistoryTab(weeks: true)])`; `NavigationBar` with destinations Now (`Icons.bolt`), Days (`Icons.calendar_view_day`), Weeks (`Icons.calendar_view_week`). `KeepScreenOn.turnOn()` in `initState` / `turnOff()` in `dispose` with the same `!kIsWeb && (Android||iOS)` guard as `lib/main.dart:127-146`.
- `main.dart` becomes: `main()` with the existing DevicePreview wrapper, `ChangeNotifierProvider(create: (_) => DashboardState()..init())`, `MaterialApp(theme: _darkTheme, home: HomeShell())` where `_darkTheme` is the existing `ThemeData.dark().copyWith(...)` block from `lib/main.dart:75-84`, light theme and `themeMode` removed.
- Deletions: `HomePage`, `HomePageState`, `MyCard`, `MyDivider`, `ListItem`, `buildDropDownMenuItems`, `_displayTextInputDialog`, the 40-card `build()`, the footer row — all superseded. In `bar_chart.dart` remove the `Consumer<MyThemeModel>` wrapper (return the column directly; `themeModel.isDark()` call sites become the dark constant) and delete the `TopSectionWidget`/legend construction (the `showHeader` branch dies with it — remove the `showHeader` parameter reads but KEEP the parameter accepted-and-ignored? No: remove the parameter and update Task 3's smoke test to assert the legend text is absent without passing `showHeader`).

- [ ] **Step 1: Failing test**

```dart
// test/home_shell_test.dart — fake state with token set and canned data:
// asserts NavigationBar has 3 destinations; tapping 'Days' shows chip 'Cost';
// with token == null shows Onboarding step text instead.
```

Write it fully in the same style as Task 7/8 tests (fake `DashboardState`, no `MyThemeModel`).

- [ ] **Step 2: Run** — fails. **Step 3: Implement the shell, rewrite `main.dart`, delete files, fix imports across `lib/` and `test/`.**
- [ ] **Step 4: Full verification**

Run: `flutter test` (all suites), `flutter analyze` (no NEW warnings; expect the count to DROP with the deletions), and `flutter build web --release` to prove the app compiles end-to-end. Launch (`flutter run -d chrome` or web-server + browser) with a real token and eyeball all three tabs, both orientations, Settings, onboarding (clear site data first).

- [ ] **Step 5: Commit**

```bash
git add -A lib test
git commit -m "feat: tabbed shell — swap root to HomeShell, delete legacy screen and theme toggle [skip ci]"
```

---

## Follow-ups deliberately OUT of this plan

- Momentum port (own plan after Amber ships and feedback lands).
- Release/version bump — owner-triggered (removes `[skip ci]` economics: the gate only builds on version change anyway).
- fl_chart 1.x migration, shared `dashboard_core` package, security triage (tracked separately).

## Self-Review Notes

- Spec coverage: shell §1→T12, Now hero §2→T2+T7, history §4→T8+T9, chart hygiene §5→T3+T4+T5+T6 (legend), settings/onboarding/theme §6→T10+T11+T12, out-of-scope §7 respected. "Combined Days retired" — satisfied by absence (T12 deletes the old screen; no task recreates it).
- Naming check: `showHeader`, `allowPartial`, `yUnit`, `sumForDay`, `sumFeedIn`, `weekData`, `selectSite` used consistently across tasks. Task 12 removes `showHeader` again — Task 3's test is updated in the same commit; acceptable churn to keep Task 3 independently verifiable.
- Types: `weekData` is `List<List<Usage>?>` everywhere; `sumForDay` returns dollars (double).
