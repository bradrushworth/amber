import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:amber/screens/now_tab.dart';
import 'package:amber/state/dashboard_state.dart';
import 'package:amber/model/Usage.dart';
import 'package:http/http.dart' as http;

void main() {
  Widget host(DashboardState s) => ChangeNotifierProvider<DashboardState>.value(
      value: s, child: const MaterialApp(home: Scaffold(body: NowTab())));

  DashboardState stateWithPrice() {
    final s = DashboardState(fetch: (u, h, ttl) async => http.Response('[]', 200));
    s.forecastData = [
      Usage(
          type: 'CurrentInterval',
          perKwh: 18.4,
          channelType: 'general',
          duration: 30,
          descriptor: 'low',
          nemTime: DateTime.now().toIso8601String())
    ];
    return s;
  }

  testWidgets('hero shows current price and period', (t) async {
    await t.pumpWidget(host(stateWithPrice()));
    await t.pump();
    expect(find.textContaining('18.4'), findsOneWidget);
    expect(find.textContaining('Off-peak'), findsWidgets);
  });

  testWidgets(
      'portrait: buy/feed-in pairs stacked in the old order '
      '(yesterday, today, tomorrow)', (t) async {
    // Tall enough that all six cards fit without scrolling, so their
    // vertical positions can be compared in a single frame.
    t.view.physicalSize = const Size(600, 4000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await t.pumpWidget(host(stateWithPrice()));
    await t.pump();

    const titles = [
      'Buy price — yesterday',
      'Feed-in price — yesterday',
      'Buy price — today',
      'Feed-in price — today',
      'Buy price — tomorrow',
      'Feed-in price — tomorrow',
    ];
    // Each title exists exactly once, and they appear top-to-bottom in the
    // pre-overhaul GridView order.
    double lastDy = -1;
    for (final title in titles) {
      final finder = find.text(title);
      expect(finder, findsOneWidget, reason: title);
      final dy = t.getTopLeft(finder).dy;
      expect(dy, greaterThan(lastDy), reason: '$title out of order');
      lastDy = dy;
    }
  });

  testWidgets('landscape: each day\'s buy and feed-in charts sit side by side',
      (t) async {
    t.view.physicalSize = const Size(1200, 600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await t.pumpWidget(host(stateWithPrice()));
    await t.pump();

    final buy = find.text('Buy price — yesterday');
    final feed = find.text('Feed-in price — yesterday');
    await t.scrollUntilVisible(buy, 200);
    expect(buy, findsOneWidget);
    expect(feed, findsOneWidget);
    // Same row: identical vertical position, buy on the left.
    expect(t.getTopLeft(buy).dy, t.getTopLeft(feed).dy);
    expect(t.getTopLeft(buy).dx, lessThan(t.getTopLeft(feed).dx));
  });
}
