# UI Overhaul — Amber Electric & Momentum Energy Dashboards

**Date:** 2026-08-22
**Status:** Approved design, pending implementation plan
**Applies to:** `bradrushworth/amber` and `bradrushworth/momentumenergy`
**Decided via:** visual brainstorm (mockups in `.superpowers/brainstorm/38671-1787403258/content/`, local only)

## Summary

Replace the dropdown-driven single screen in both apps with a tabbed shell:
a "hero" tab answering each app's core question at a glance, plus history
tabs whose layout adapts by orientation. Chart hygiene is fixed throughout;
the existing chart visual style and dark identity are deliberately kept.

**Sequencing decision (option A):** the UI is built app-by-app — Amber
first, then ported to Momentum — WITHOUT waiting for a shared package.
The owner accepts that shell code is written twice and that a future
`dashboard_core` extraction will touch it again. The security triage from
the 2026-08-20 review (keystore rotation/purge, bundled personal CSV)
remains scheduled before or alongside this work and is not part of this
spec.

## 1. Shared shell (both apps)

- Bottom `NavigationBar` replaces the view dropdown.
  - Amber tabs: **Now / Days / Weeks**
  - Momentum tabs: **Data / Days / Weeks**
- Slim app bar: app name + context line (Amber: selected site's friendly
  label; Momentum: loaded file's date range). Gear icon opens Settings.
- The permanent footer link row (Support / Improvements / Source Code /
  Buy Coffee / Chart Library / Report Issue) is removed from the main
  screen and becomes an About entry inside Settings.
- The old "Combined Days" view is retired; its use case (multi-day
  aggregate) is covered by the Weeks tab. (YAGNI: do not port it.)

## 2. Amber "Now" tab

- Hero panel: current price, large; beneath it the tariff period, spike
  status, and "today so far $X"; today's price chart inline in the panel.
- Below the hero: Yesterday and Tomorrow forecast cards (buy + feed-in).
- Site selection moves out of the header row: the app-bar context line is
  tappable, opening a site sheet (active sites first, closed badged —
  behaviour shipped in v0.7.5).
- Data comes from the existing 1-minute forecast timer + ApiCache; "today
  so far" sums today's cost records (already fetched for Recent Days).

## 3. Momentum "Data" tab

- Hero panel: file summary — date range (from the parsed data, never the
  clock), filename, meter count, totals row (total cost / total kWh /
  average $ per day), and a prominent **Import** button.
- Below the hero: the most recent days' cards.
- Import keeps the existing `file_picker` flow (UTF-8 decode, single- and
  multi-meter support shipped in v1.3.3).

## 4. History tabs (Days and Weeks, both apps)

- **Portrait:** single-column feed of date-titled cards, newest first.
  Chips select the metric: **Cost / Usage / Prices** (Amber) or
  **Cost / Usage** (Momentum). One metric at a time.
- **Landscape:** each day (or week) is a ROW containing the
  **Usage | Cost pair side by side**, with column headers, so each column
  reads as a single metric top-to-bottom. This preserves the original
  two-column pairing rationale and makes the pairing structural (a
  missing chart can no longer shift the grid out of alignment).
- Weeks tab: identical pattern over 7-day aggregates. A partial current
  week renders with the days it has — never a "Not enough data" void.
- Tapping any card opens a full-screen single-day (or single-week) view:
  big chart + totals row (day total $, kWh used, feed-in $).
- Card titles are real dates ("Thu 21 Aug"), derived from the data.

## 5. Charts

- **Visual style is unchanged** (explicit decision): saturated tariff
  palette, rounded bar caps, visible gaps. Green off-peak / red peak /
  cyan solar-sponge / yellow feed-in / orange shoulder / pink controlled
  / blue supply all keep their meanings.
- Hygiene fixes around that style:
  - ONE legend per screen (under the app bar or above the feed), never
    repeated per card; "Sponge" gets a long label ("Solar Sponge").
  - Axis units everywhere: kWh, $, c/kWh; y-labels formatted so adjacent
    labels are never duplicates or collisions.
  - X-axis labelled every 3–6 hours, horizontal text.
  - Card titles never collide with anything (legend removed from cards).
  - Tap tooltip shows time + value + unit + tariff period, dismisses on
    tap-away; no sticky bare-number tooltips.
  - Loading = skeleton bars; empty = compact one-line message, not a
    full-height void.
- Naming: "Buy price" and "Feed-in price" replace "Price"/"Prices".

## 6. Settings, onboarding, errors

- Settings screen (both apps): Amber — API token entry (moved from the
  header dialog; accepts any non-empty token, no 36-char gate);
  Momentum — tariff rates (exists since v1.3.3, moves here); both —
  About (the former footer links + version).
- First-run onboarding replaces the permanent header instructions: a
  simple empty-state screen with numbered steps (Amber: generate token →
  paste; Momentum: export CSV → import) shown only until data exists.
- Errors are friendly and actionable ("Token expired — update it in
  Settings"), never raw response bodies. (Partly shipped in v0.7.5.)
- Theme: commit to dark; delete `MyThemeModel`, the light theme, and the
  dead toggle.

## 7. Explicitly out of scope

- Chart bar restyling (kept as-is), any new data sources, notifications,
  home-screen widgets, the shared `dashboard_core` package (deferred by
  sequencing decision A), fl_chart 1.x migration (separate project),
  state-management rework beyond what the tabs force.

## Implementation notes

- Amber first, then Momentum port. Each app ships behind its normal
  release process (version bump → Codemagic).
- The tab shell forces minimal state extraction in Amber (current
  `HomePageState` fields move to a small `ChangeNotifier` shared by
  tabs); keep it boring — Provider is already a dependency.
- `BarChartWidget1`'s per-card legend/title rendering is bypassed rather
  than rewritten: cards get a simple title row; the shared legend is a
  new widget.
- Landscape pairing is a `LayoutBuilder`/`OrientationBuilder` switch in
  the history feed, not a separate screen.
- Existing aggregation (`DataAggregator`) and fetch/cache layers are
  reused untouched except where titles/units require passing dates.
