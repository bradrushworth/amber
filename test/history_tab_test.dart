import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:amber/my_theme_model.dart';
import 'package:amber/screens/history_tab.dart';
import 'package:amber/state/dashboard_state.dart';

import 'test_data.dart';

DashboardState _buildState() {
  final s = DashboardState(fetch: (u, h, ttl) async => http.Response('[]', 200));
  s.weekData[0] = day();
  return s;
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
}
