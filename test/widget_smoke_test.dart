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
        prices: true)));
    await t.pump();
    // The old TopSectionWidget header (chart title + per-card legend) is gone:
    // titles live on ChartCard and the legend is one LegendBar per tab.
    expect(find.text('Thu 21 Aug'), findsNothing);
    expect(find.text('Peak'), findsNothing);
  });

  testWidgets(
      'a reused BarChartState re-aggregates when the metric flags change',
      (t) async {
    // Same type, same position, no key: Flutter reuses the State. The chart
    // must still follow the new flags (it used to latch the first metric).
    await t.pumpWidget(host(BarChartWidget1(
        day(), 'Thu 21 Aug', 30, const Duration(days: 1),
        prices: true)));
    await t.pump();
    expect(find.textContaining('\$'), findsWidgets);
    expect(find.textContaining('kWh'), findsNothing);

    await t.pumpWidget(host(BarChartWidget1(
        day(), 'Thu 21 Aug', 30, const Duration(days: 1))));
    await t.pump();
    // The y axis is now in kWh, derived internally — no caller-supplied unit.
    expect(find.textContaining('kWh'), findsWidgets);
    expect(find.textContaining('\$'), findsNothing);
  });

  testWidgets('the y axis prints exactly one unit', (t) async {
    await t.pumpWidget(host(BarChartWidget1(
        day(), 'Thu 21 Aug', 30, const Duration(days: 1),
        prices: true)));
    await t.pump();
    // '$0.10', never '$0.10$' or '$0.10c' (the old doubled yUnit).
    for (final text in t.widgetList<Text>(find.textContaining('\$'))) {
      expect(text.data, matches(r'^\$-?\d+\.\d+$'), reason: text.data);
    }
  });

  testWidgets('ChartCard renders title and trailing', (t) async {
    await t.pumpWidget(host(const ChartCard(
        title: 'Thu 21 Aug', trailing: '\$7.43', chart: SizedBox())));
    await t.pump();
    expect(find.text('Thu 21 Aug'), findsOneWidget);
    expect(find.text('\$7.43'), findsOneWidget);
  });
}
