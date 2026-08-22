import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amber/bar_chart.dart';
import 'package:amber/widgets/chart_card.dart';

import 'test_data.dart';

Widget host(Widget child) =>
    MaterialApp(home: Scaffold(body: SizedBox(height: 300, child: child)));

void main() {
  testWidgets('the chart renders no title/legend header of its own', (t) async {
    await t.pumpWidget(host(BarChartWidget1(
        day(), 'Thu 21 Aug', 30, const Duration(days: 1),
        prices: true, yUnit: '\$')));
    await t.pump();
    // The old TopSectionWidget header (chart title + per-card legend) is gone:
    // titles live on ChartCard and the legend is one LegendBar per tab.
    expect(find.text('Thu 21 Aug'), findsNothing);
    expect(find.text('Peak'), findsNothing);
  });

  testWidgets('ChartCard renders title and trailing', (t) async {
    await t.pumpWidget(host(const ChartCard(
        title: 'Thu 21 Aug', trailing: '\$7.43', chart: SizedBox())));
    await t.pump();
    expect(find.text('Thu 21 Aug'), findsOneWidget);
    expect(find.text('\$7.43'), findsOneWidget);
  });
}
