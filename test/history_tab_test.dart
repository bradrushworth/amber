import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:amber/bar_chart.dart';
import 'package:amber/model/Usage.dart';
import 'package:amber/screens/history_tab.dart';
import 'package:amber/state/dashboard_state.dart';
import 'package:amber/state/day_math.dart';
import 'package:amber/widgets/chart_card.dart';

import 'test_data.dart';

DashboardState _buildState() {
  final s = DashboardState(fetch: (u, h, ttl) async => http.Response('[]', 200));
  s.weekData[0] = day();
  return s;
}

/// Two consecutive days (48 half-hourly 'general' records apiece, same
/// per-record shape as [day]) so a 7-day window sums more than one day's
/// worth of data — needed to distinguish sumForDay from sumForRange.
List<Usage> _twoDayWeek() {
  List<Usage> oneDay(String date, DateTime base) => List.generate(
      48,
      (i) => Usage(
          type: 'ActualInterval', duration: 30, date: date,
          nemTime:
              base.add(Duration(minutes: (i + 1) * 30)).toIso8601String(),
          kwh: 1.0, cost: 10.0, perKwh: 20.0,
          channelType: 'general', channelIdentifier: 'E1'));
  return [
    ...oneDay('2023-08-11', DateTime.utc(2023, 8, 10, 14, 0)),
    ...oneDay('2023-08-12', DateTime.utc(2023, 8, 11, 14, 0)),
  ];
}

/// 48 half-hourly 'general' records for [date] (an AEST calendar date),
/// mirroring the shape of [day].
List<Usage> _dayOf(String date, {double kwh = 1.0, double cost = 10.0}) {
  final base = DateTime.parse('${date}T00:00:00+10:00');
  return List.generate(
      48,
      (i) => Usage(
          type: 'ActualInterval', duration: 30, date: date,
          nemTime: base.add(Duration(minutes: (i + 1) * 30)).toIso8601String(),
          kwh: kwh, cost: cost, perKwh: 20.0,
          channelType: 'general', channelIdentifier: 'E1'));
}

Widget _host(Widget child, DashboardState s) =>
    ChangeNotifierProvider<DashboardState>.value(
        value: s, child: MaterialApp(home: Scaffold(body: child)));

/// All the [BarChartWidget1]s currently in the tree, as widgets (so their
/// configuration — not just the card's trailing text — can be asserted).
Finder _charts({bool? prices, bool? forecast}) => find.byWidgetPredicate((w) =>
    w is BarChartWidget1 &&
    (prices == null || w.prices == prices) &&
    (forecast == null || w.forecast == forecast));

void main() {
  testWidgets('portrait: chips render and switching to Usage swaps cards',
      (t) async {
    // The default test surface (800x600) is landscape-shaped; force a
    // portrait size so MediaQuery.orientation reports portrait.
    final originalSize = t.view.physicalSize;
    final originalRatio = t.view.devicePixelRatio;
    t.view.physicalSize = const Size(400, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(() {
      t.view.physicalSize = originalSize;
      t.view.devicePixelRatio = originalRatio;
    });

    final s = _buildState();
    await t.pumpWidget(_host(const HistoryTab(weeks: false), s));
    await t.pump();

    expect(find.text('Cost'), findsOneWidget);
    expect(find.text('Usage'), findsOneWidget);
    expect(find.text('Prices'), findsOneWidget);
    // Default metric is Cost: no ' kWh' trailing text yet.
    expect(find.textContaining(' kWh'), findsNothing);
    // ...and every chart in the feed is actually configured as a cost chart.
    expect(_charts(prices: true, forecast: false), findsWidgets);
    expect(_charts(prices: false), findsNothing);

    await t.tap(find.text('Usage'));
    await t.pump();

    // Usage metric swaps in ' kWh' trailing cards.
    expect(find.textContaining(' kWh'), findsWidgets);
    // The CHART must follow the chip, not just the card's trailing text: a
    // usage chart is prices == false. (Regression: BarChartState cached
    // prices/forecast in `late final` fields, so a reused State kept drawing
    // the first metric for ever while the labels changed.)
    expect(_charts(prices: false, forecast: false), findsWidgets);
    expect(_charts(prices: true), findsNothing);

    await t.tap(find.text('Prices'));
    await t.pump();

    expect(_charts(prices: true, forecast: true), findsWidgets);
    expect(_charts(forecast: false), findsNothing);
  });

  testWidgets('day titles come from the data, not the clock', (t) async {
    final originalSize = t.view.physicalSize;
    final originalRatio = t.view.devicePixelRatio;
    t.view.physicalSize = const Size(400, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(() {
      t.view.physicalSize = originalSize;
      t.view.devicePixelRatio = originalRatio;
    });

    // A fixture whose newest date is far behind DateTime.now() — exactly what
    // the Amber usage endpoint looks like when it lags.
    final s = DashboardState(fetch: (u, h, ttl) async => http.Response('[]', 200));
    s.weekData[0] = [..._dayOf('2023-08-11'), ..._dayOf('2023-08-12')];

    await t.pumpWidget(_host(const HistoryTab(weeks: false), s));
    await t.pump();

    // First card = the data's own last date, NOT yesterday-by-the-clock.
    expect(find.text('Sat 12 Aug'), findsOneWidget);
    expect(find.text('Fri 11 Aug'), findsOneWidget);
    final clockTitle =
        DateFormat('E d MMM').format(DateTime.now().subtract(const Duration(days: 1)));
    expect(clockTitle, isNot('Sat 12 Aug')); // guard: the fixture really is stale
    expect(find.text(clockTitle), findsNothing);

    // The price (forecast) charts must be anchored on that same data-derived
    // instant instead of DateTime.now(), or they'd draw a different day from
    // the cost/usage cards sitting beside them.
    await t.tap(find.text('Prices'));
    await t.pump();
    final priceChart = t.widgetList<BarChartWidget1>(_charts(forecast: true)).first;
    expect(priceChart.anchor, DateTime.parse('2023-08-13T00:00:00+10:00'));
  });

  testWidgets('weeks: the leading card is a real current week including today',
      (t) async {
    final originalSize = t.view.physicalSize;
    final originalRatio = t.view.devicePixelRatio;
    t.view.physicalSize = const Size(400, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(() {
      t.view.physicalSize = originalSize;
      t.view.devicePixelRatio = originalRatio;
    });

    final week = _dayOf('2023-08-12');
    final today = _dayOf('2023-08-13', kwh: 2.0, cost: 25.0);
    final s = DashboardState(fetch: (u, h, ttl) async => http.Response('[]', 200));
    s.weekData[0] = week;
    s.todayUsage = today;

    await t.pumpWidget(_host(const HistoryTab(weeks: true), s));
    await t.pump();

    // The leading row is titled from ITS OWN data (which now runs to the
    // 13th), while the w=0 row still ends on the 12th — no more duplicate.
    expect(find.text('Week to Sun 13 Aug'), findsOneWidget);
    expect(find.text('Week to Sat 12 Aug'), findsOneWidget);

    final withToday =
        sumForRange([...week, ...today], const Duration(days: 7), Duration.zero, cost: true);
    final withoutToday =
        sumForRange(week, const Duration(days: 7), Duration.zero, cost: true);
    expect(withToday, greaterThan(withoutToday));
    expect(find.text('\$${withToday.toStringAsFixed(2)}'), findsOneWidget);
    expect(find.text('\$${withoutToday.toStringAsFixed(2)}'), findsOneWidget);
  });

  testWidgets('landscape: shows column headers and no chips', (t) async {
    final originalSize = t.view.physicalSize;
    final originalRatio = t.view.devicePixelRatio;
    t.view.physicalSize = const Size(1600, 720);
    t.view.devicePixelRatio = 1;
    addTearDown(() {
      t.view.physicalSize = originalSize;
      t.view.devicePixelRatio = originalRatio;
    });

    final s = _buildState();
    await t.pumpWidget(_host(const HistoryTab(weeks: false), s));
    await t.pump();

    expect(find.text('USAGE (kWh)'), findsOneWidget);
    expect(find.text('COST (\$)'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
  });

  testWidgets(
      'weeks: "Week to" card trailing sums the full week, not one day',
      (t) async {
    final originalSize = t.view.physicalSize;
    final originalRatio = t.view.devicePixelRatio;
    t.view.physicalSize = const Size(400, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(() {
      t.view.physicalSize = originalSize;
      t.view.devicePixelRatio = originalRatio;
    });

    final weekData = _twoDayWeek();
    final s = DashboardState(fetch: (u, h, ttl) async => http.Response('[]', 200));
    s.weekData[0] = weekData;

    await t.pumpWidget(_host(const HistoryTab(weeks: true), s));
    await t.pump();

    expect(find.textContaining('Week to'), findsWidgets);

    // Default metric is Cost. The trailing figure must be the 7-day sum, not
    // sumForDay's one-day sum (which would only capture 2023-08-12, half the
    // total).
    final fullWeek = sumForRange(weekData, const Duration(days: 7), Duration.zero, cost: true);
    final oneDay = sumForDay(weekData, Duration.zero, cost: true);
    expect(fullWeek, isNot(closeTo(oneDay, 0.001)));
    // Exactly once: with no todayUsage the "current week" IS weekData[0], so
    // the leading card is suppressed rather than duplicating the w=0 row.
    expect(find.text('\$${fullWeek.toStringAsFixed(2)}'), findsOneWidget);
  });

  testWidgets('weeks: no duplicate leading card when today has not arrived',
      (t) async {
    final originalSize = t.view.physicalSize;
    final originalRatio = t.view.devicePixelRatio;
    t.view.physicalSize = const Size(400, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(() {
      t.view.physicalSize = originalSize;
      t.view.devicePixelRatio = originalRatio;
    });

    final s = DashboardState(fetch: (u, h, ttl) async => http.Response('[]', 200));
    s.weekData[0] = _dayOf('2023-08-12');
    s.todayUsage = const [];      // Amber's usage feed routinely lags

    await t.pumpWidget(_host(const HistoryTab(weeks: true), s));
    await t.pump();

    expect(find.text('Week to Sat 12 Aug'), findsOneWidget);
  });

  testWidgets('portrait: tapping the first card pushes a day-detail route',
      (t) async {
    final originalSize = t.view.physicalSize;
    final originalRatio = t.view.devicePixelRatio;
    t.view.physicalSize = const Size(400, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(() {
      t.view.physicalSize = originalSize;
      t.view.devicePixelRatio = originalRatio;
    });

    final s = _buildState();
    await t.pumpWidget(_host(const HistoryTab(weeks: false), s));
    await t.pump();

    // Titles are data-derived: [day] is a single 2023-08-12 fixture.
    const firstTitle = 'Sat 12 Aug';

    // Tap the card's center (which falls inside the chart body): the chart
    // is wrapped in IgnorePointer for history-feed cards, so navigation
    // wins over the chart's own tooltip gesture handling here.
    await t.tap(find.byType(ChartCard).first);
    await t.pumpAndSettle();

    expect(
        find.descendant(of: find.byType(AppBar), matching: find.text(firstTitle)),
        findsOneWidget);
  });
}
