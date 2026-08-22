import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:amber/my_theme_model.dart';
import 'package:amber/model/Usage.dart';
import 'package:amber/screens/history_tab.dart';
import 'package:amber/state/dashboard_state.dart';
import 'package:amber/state/day_math.dart';

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

Widget _host(Widget child, DashboardState s) => MultiProvider(providers: [
      ChangeNotifierProvider<DashboardState>.value(value: s),
      ChangeNotifierProvider(create: (_) => MyThemeModel()),
    ], child: MaterialApp(home: Scaffold(body: child)));

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

    await t.tap(find.text('Usage'));
    await t.pump();

    // Usage metric swaps in ' kWh' trailing cards.
    expect(find.textContaining(' kWh'), findsWidgets);
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

    // Default metric is Cost. The leading "This week (partial)" card and the
    // w=0 "Week to ..." card both cover the same (data, duration, ending),
    // so the full-week total from sumForRange should appear twice — proving
    // the trailing figure is the 7-day sum, not sumForDay's one-day sum
    // (which would only capture 2023-08-12, half the total).
    final fullWeek = sumForRange(weekData, const Duration(days: 7), Duration.zero, cost: true);
    final oneDay = sumForDay(weekData, Duration.zero, cost: true);
    expect(fullWeek, isNot(closeTo(oneDay, 0.001)));
    expect(find.text('\$${fullWeek.toStringAsFixed(2)}'), findsNWidgets(2));
  });
}
