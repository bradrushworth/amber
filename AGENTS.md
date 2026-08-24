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
  stale-served-on-error; in-flight dedup; `clear()` on token change.
- `lib/periods.dart` — pure, testable period/DST math for the
  `prices/current` fetch window.
- `lib/model/Sites.dart`, `lib/model/Usage.dart` — nullable-field JSON bags.
- `lib/utils.dart` — timezone pinning + colour helpers.

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
- `daily` in `bar_chart.dart` is a hardcoded supply charge (known debt; the
  sister app grew a Settings dialog for its rates — same treatment planned
  here). `day_math.sumForRange` imports it and adds `daily * duration.inDays`
  to every cost total, so a card's trailing figure matches the supply
  segments the chart draws. Keep the two in step.

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
`test/api_cache_test.dart` (TTL/dedup/stale-on-error),
`test/day_math_test.dart` (card totals), `test/dashboard_state_test.dart`
(site selection, stale-response guards, offline degradation).

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

## Store assets and the app icon

`store/` holds everything the Play Store / App Store listings are built from,
so the repo is the record of what is published:

- `store/listing.md` — app name, short/full description, "What's new". Edit here
  first, then paste into the console.
- `store/screenshots/` — `play-*` 1080x1920, `ios-*` 1290x2796 (iPhone 6.7"),
  `land-*` 1600x800. Regenerated from a real `flutter build web --release`
  driven by headless Chrome, never mocked up.
- `store/feature-graphic.png` (1024x500, Play only), `store/icon-512.png`.

The launcher icon is generated, not hand-drawn: `assets/icon.png` (full-bleed
1024x1024) and `assets/icon_foreground.png` (same art, transparent) feed
`flutter_launcher_icons`. After changing either, run:

```bash
dart run flutter_launcher_icons
```

`adaptive_icon_foreground` is wrapped in a 16% inset by the generator, so the
foreground must use the SAME geometry as the full icon — pre-shrinking it a
second time makes the launcher icon look tiny.

## Gotchas

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
