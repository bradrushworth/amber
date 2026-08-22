import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:amber/bar_chart.dart';
import 'package:amber/my_theme_model.dart';
import 'package:amber/widgets/chart_card.dart';

import 'test_data.dart';

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

  testWidgets('ChartCard renders title and trailing', (t) async {
    await t.pumpWidget(host(const ChartCard(
        title: 'Thu 21 Aug', trailing: '\$7.43', chart: SizedBox())));
    await t.pump();
    expect(find.text('Thu 21 Aug'), findsOneWidget);
    expect(find.text('\$7.43'), findsOneWidget);
  });
}
