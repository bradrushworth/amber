# AGENTS.md — Amber Electric Dashboard

Canonical guide for AI agents and new contributors. `.clinerules` carries an
older copy of much of this for Cline compatibility; when they disagree, this
file wins.

## What this is

A Flutter app (Android / iOS / web) that visualises a customer's
[Amber Electric](https://amber.com.au) (Australian retailer, wholesale price
passthrough) electricity prices, usage, and costs as a wall of bar charts.
Three tabs (Now / Days / Weeks) behind a nav bar, still designed to run
landscape as a glanceable always-on board (`keep_screen_on`).

**Sister app:** `../momentumenergy` is a near-clone for Momentum Energy
(CSV-import instead of API). `screenshots_*.dart` and most of `utils.dart` are
copy-paste twins, and the `bar_chart.dart` skeleton matches. (`my_theme_model.dart`
and `top_section.dart` were deleted here in the UI overhaul — the Momentum
twins still exist on their side, so a port of anything touching them has to be
hand-translated.) Fixes to shared-shaped code are manually ported between repos
(see commits referencing "from Amber app"); a shared package is planned but
does not exist yet. When you fix something in a twin file, say so, so the port
isn't forgotten.

## Commands

```bash
flutter pub get      # deps
flutter test         # 75+ unit + widget tests, must stay green
flutter analyze      # ~50 pre-existing style warnings are the baseline;
                     # any NEW error/warning is a regression
flutter build web --release   # local web build (serves fine from build/web)
```

## Architecture

The UI overhaul split the old single `main.dart` screen into a state object
plus a tabbed shell: `lib/state/dashboard_state.dart` (`DashboardState`, a
`ChangeNotifier` provided via `package:provider`) owns the API token
(SharedPreferences, key `amberToken`), the site list/selection, the two
polling timers (1-min forecast, 1-hr usage, started before the first `await`
in `init()` so an offline launch still recovers), `forecastData` /
`weekData[0..3]` / `todayUsage`, and a user-facing `lastError`; every fetcher
is generation-guarded (`_gen`) and swallows transport failures into
`lastError`. `lib/screens/` holds the views — `home_shell.dart` (nav bar,
site picker, error banner), `now_tab.dart`, `history_tab.dart` (Days/Weeks
feed, metric chips), `day_detail.dart`, `settings_screen.dart`,
`onboarding.dart` — with small presentational pieces in `lib/widgets/`
(`ChartCard`, `LegendBar`) and the card-total arithmetic in
`lib/state/day_math.dart`. `lib/main.dart` is now just app bootstrap + theme.

- `lib/bar_chart.dart` — `BarChartWidget1` (fl_chart view) + `DataAggregator`
  (bucketing/summing/pricing domain logic, unit-tested).
- `lib/api_cache.dart` — singleton TTL cache + rate-limit guard in front of
  `package:http`. ALL Amber HTTP calls go through it, never `http.get`
  directly. Forecast TTL = one meter interval; usage TTL = 1 hour;
  stale-served-on-error; in-flight dedup; `clear()` on token change. Cache
  keys are `'<Authorization header> <uri>'`, not just the URL — otherwise a
  new token that Amber rejects could be answered with a DIFFERENT (previous)
  token's cached good response for the same endpoint (a false "connected"),
  and the error back-off would then reject a just-corrected token without
  ever reaching the network.
- `lib/periods.dart` — pure, testable period/DST math for the
  `prices/current` fetch window.
- `lib/model/Sites.dart`, `lib/model/Usage.dart` — nullable-field JSON bags.
- `lib/utils.dart` — timezone pinning + colour helpers. `Utils.launchURI`
  never throws (returns `Future<bool>`, false if nothing could open the URI)
  — callers fire-and-forget it from `onTap`.

### Connecting an Amber account (added Sep 2026)

- `DashboardState.connect(String raw)` validates length (36 chars) and then
  the candidate token itself — a live `/sites` fetch with the CANDIDATE
  token's headers, via `_fetch`, BEFORE touching any state — and returns
  null on success or a short human error string on failure. On failure
  NOTHING changes (current token/sites/data/prefs untouched); only on Amber
  actually accepting the token does it install it (same site-selection rule
  as `loadSites`: last non-closed site, else last), persist it, clear the
  cache, and kick off the pollers. This replaced the old `saveToken`, which
  persisted the token BEFORE knowing Amber would accept it — a rejected
  token used to flip the whole app to an empty state with no way back.
- `DashboardState.tokenRejected` is set when a SAVED token stops being
  accepted (401/403 from `loadSites`, e.g. revoked or regenerated
  elsewhere) — distinct from `connect()` rejecting a candidate that was
  never saved. `HomeShell` shows the onboarding guide instead of the tabs
  whenever `token == null || (tokenRejected && sites.isEmpty)`.
- `DashboardState.removeToken()` forgets the saved token/site/data and clears
  the `amberToken` pref, sending the user back to the guide. Settings'
  "Remove token from this device" confirms with an `AlertDialog` first.
- `lib/screens/onboarding.dart` — `Onboarding` (numbered `_Step` rows,
  `_ErrorNote`, the token `TextField` + paste button + Connect) is both what
  `HomeShell` shows in place of the tabs and the body of
  `ConnectAmberScreen`, pushed by `openAmberGuide(context)` from Settings'
  "Change token". `amberDevelopersUri` (`app.amber.com.au/developers`,
  verified live 2026-09-23) is where a token is generated.

### Amber API

Base `https://api.amber.com.au/v1`, bearer token (user-generated at
app.amber.com.au → For Developers). Endpoints used: `/sites`,
`/sites/{id}/prices/current?next=&previous=&resolution=`,
`/sites/{id}/usage?startDate=&endDate=`. CORS is open (`*`), so the web build
works. `/sites` includes **closed** sites; the picker badges them "(closed)"
and defaults to the most recent **active** site — keep that behaviour.

### Async conventions (added Aug 2026 — keep these invariants)

- Every fetcher guards `token == null || selectedSite == null` before doing
  anything (timers start at the top of `init()`, before a token may exist).
- Every fetcher captures `final site = selectedSite!` and `final gen = _gen`
  up front and, after each await, bails if `_isDisposed` or `gen != _gen` —
  this is what prevents mixed-site data in `weekData`. Do not remove.
- Error paths set a short human `lastError` and `return`; never
  snackbar-then-throw, never surface raw response bodies. The network+parse
  body of each fetcher is wrapped in `try/catch` so an offline launch (or a
  timer tick with no network) degrades to a banner instead of an unhandled
  async error — `DashboardState.offlineMessage`.

## Chart aggregation model (do not "improve" without reading)

- Bars are per-interval buckets; `graphPos = hour * periodsPerHour +
  minute ~/ interval`. Historical charts cap the interval at 15 min
  (`history_tab.dart`) so 5-minute sites don't draw 288 bars; forecast charts
  cap at 30 (`now_tab.dart`; AEMO forecasts are 30-min).
- Usage (kWh) and cost ($) are **summed** into a bar; forecast prices
  (perKwh) are **averaged** (`CustomRodElement.displayAmount`). Forecast uses
  `perKwh` only, never `cost`.
- **Daily supply charge**: added once per `(day, graphPos)` via the
  `supplyAdded` set, at `daily / barsPerDay` — the divisor MUST track bars
  per day (a fixed /48 doubled the charge on 15-minute bars; regression test
  "Supply charge divisor tracks bars per day"). The per-bar amount is
  intentionally NOT pre-rounded; display rounding happens in `makeRodData`.
- `aggregateData` iterates every record once and buckets on its own
  `nemTime`/channel. Never reintroduce a fixed meter-stride — the API
  interleaves channels/days.
- **`nemTime` is the END of an interval**, so a record starts at
  `nemTime - record.duration`. Subtract the RECORD's own duration, never the
  chart's bar width: `dashboard_state` requests
  `prices/current?resolution=<site interval>`, so a 5-minute site returns
  5-minute price records that the Now tab then draws on 30-minute bars. While
  the code subtracted the bar width, five of every six readings fell into the
  previous half hour and a genuinely cheap 06:30 rendered at the expensive
  07:00 price (verified against the API and Amber's own app for 2026-08-25:
  06:30 settled at 22c, the app drew 31c). Regression test
  `test/interval_bucketing_test.dart`. Usage charts were never affected —
  there the records and the bars are both the site interval, which is exactly
  why this hid for so long. Momentum's CSV takes the OPPOSITE convention (its
  timestamps are interval STARTS), so do not port this subtraction there --
  `momentumenergy/test/interval_convention_test.dart` guards it.
- `daily` in `bar_chart.dart` is a hardcoded supply charge (known debt; the
  sister app grew a Settings dialog for its rates — same treatment planned
  here). `day_math.sumForRange` imports it and adds `daily * duration.inDays`
  to every cost total, so a card's trailing figure matches the supply
  segments the chart draws. Keep the two in step.
- **Bar width** (`barWidthFor(chartWidth, barCount)`, ported from the
  Momentum twin): ~70% of each bar's slot (`(chartWidth - leftAxisReservedSize)
  / barCount`), clamped 1.5..24px. `BarChartState.build` wraps the chart in a
  `LayoutBuilder` and re-sizes every rod to the card's actual width via
  `group.copyWith`/`rod.copyWith` — the old fixed 2/4/7px-by-interval widths
  in `makeRodData` are now just an unused-at-render placeholder (comment
  says so; don't delete the field, `BarChartRodData` needs a `width`).
  `leftAxisReservedSize` is a single top-level const shared by `barWidthFor`
  and the chart's `leftTitles.reservedSize` — don't let them drift apart.
  Every rod gets a uniform 2px radius (fl_chart's unset default is width / 2,
  a pill once bars are wide). Not a flat-base/rounded-top split like
  Momentum's: the feed-in backdrop (`backDrawRodData`) reuses the rod's
  radius and fl_chart does not flip corners for negative bars, so that split
  would round feed-in's axis edge and square its tip. `BarChartData.groupsSpace` does nothing under the
  default `spaceEvenly` group alignment fl_chart uses here — don't
  reintroduce it as a spacing knob.

## Timezone / DST (critical, NSW)

The Amber API is DST-blind: timestamps are always AEST +10, never AEDT.
`Utils.toLocal` pins to +10 (`pinToAest`) — it must never call
`DateTime.toLocal()`. `periods.dart` handles the two 23h/25h DST transition
days via `dstAdjustmentHours`. Aggregation therefore always sees 48 half-hour
AEST slots per day. Forecast tabs anchor on the real current AEST day via
`DataAggregator.nowOverride`; historical charts and unit tests anchor on the
data's own last date (fixtures use fixed 2023 dates — inject `nowOverride` in
tests, never depend on `DateTime.now()`).

## Tests

Unit: `test/bar_chart_test.dart` (aggregation incl. 5-min/15-min/30-min,
supply charge, SA fixture data), `test/periods_test.dart` (DST windows),
`test/api_cache_test.dart` (TTL/dedup/stale-on-error, and token-keying: a
401 for one token is never answered with another token's cached 200),
`test/day_math_test.dart` (card totals), `test/dashboard_state_test.dart`
(site selection, stale-response guards, offline degradation, `connect()`
success/401/wrong-length/empty-sites/offline, `loadSites` setting
`tokenRejected`, `removeToken`).

Widget: `test/widget_test.dart`, `test/widget_smoke_test.dart`,
`test/home_shell_test.dart`, `test/now_tab_test.dart`,
`test/history_tab_test.dart`, `test/settings_test.dart`,
`test/onboarding_test.dart`. Shared fixtures live in `test/test_data.dart`.
Widget tests that exercise the history feed must force a portrait surface
(`t.view.physicalSize`) — the default 800x600 test window is landscape, which
hides the metric chips.

## Git, releases, CI

- Line endings are normalized via `.gitattributes` (`* text=auto`, binaries
  excluded) since Aug 2026: repo stores LF, Windows checkouts are CRLF.
  Don't hand-craft `\r\n` in edits any more.
- Branch + PR to `master` for non-trivial changes; direct commits to master
  are the historical norm for small fixes/bumps.
- Release = bump `version: x.y.z+build` in `pubspec.yaml` (both numbers move;
  build increments by 1), commit "Bump version to x.y.z+build: <summary>",
  push `master`. Codemagic (dashboard-configured, no `codemagic.yaml`) builds
  web/Android/iOS from master pushes. No git tags.

## Security & privacy (public repo!)

- The in-app "Source Code" link points here — treat the repo as public.
- NEVER commit: API tokens, real NMIs/usage exports, keystores, or
  `key.properties`. Historical debt: `keys/keystore.jks` is already tracked
  (rotation via Play App Signing is the accepted fix; don't make it worse).
- The user's Amber token is entered in-app and stored in SharedPreferences;
  it must never appear in code, fixtures, or committed files.

## Gotchas

- `android/build.gradle` must keep TWO `subprojects` blocks: buildDir
  redirection first, `evaluationDependsOn(':app')` second (Flutter's
  template). Merged into one, any plugin whose name sorts before "app"
  evaluates `:app` with its default buildDir, the default R8 rules path goes
  stale, and `bundleRelease` fails with "Missing class
  androidx.window.extensions…" — `flutter test` stays green. It stopped the
  Momentum twin's 1.6.0+28 on CI; `test/android_build_config_test.dart`
  guards it here.
- `flutter test` can fail on a locked `build\unit_test_assets` dir on
  Windows: `Remove-Item -Recurse -Force build` and rerun.
- `git push origin master` can falsely print "Everything up-to-date"; verify
  with `git log origin/master`.
- `fl_chart` is pinned at 0.69.x; the code uses APIs removed in ≥0.70
  (`SideTitleWidget(axisSide:)`). Migrating is a deliberate project, not a
  drive-by bump.
- `device_preview_plus` is imported from `lib/main.dart` but declared under
  `dev_dependencies` — works, but don't copy the pattern.
- Analyzer baseline is dirty (~50 style warnings). Fix opportunistically;
  never add new ones.
