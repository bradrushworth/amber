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
