import 'package:fl_chart/fl_chart.dart';
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

  group('barWidthFor', () {
    test('scales to ~70% of the per-bar slot, clamped 1.5..24', () {
      // 1000px wide, 48 bars: slot = (1000 - 40) / 48 = 20; 70% = 14.
      expect(barWidthFor(1000, 48), closeTo(14.0, 0.01));
      // A narrow phone: 300px, 48 bars: slot ≈ 5.42; 70% ≈ 3.79.
      expect(barWidthFor(300, 48), closeTo(3.79, 0.05));
      // Clamped to the floor on a very narrow/crowded chart.
      expect(barWidthFor(80, 48), 1.5);
      // Clamped to the ceiling on a wide chart with few bars.
      expect(barWidthFor(5000, 4), 24.0);
      // Non-finite width or no bars at all: fixed placeholder, never a crash.
      expect(barWidthFor(double.infinity, 48), 6);
      expect(barWidthFor(500, 0), 6);
    });
  });

  testWidgets(
      'a wider chart draws rods more than 3x wider than a narrow one, both narrower than their slot',
      (t) async {
    // The default 800x600 test surface would silently clamp a 1100px-wide
    // SizedBox down to 800; widen the surface so both cases actually get the
    // width they ask for.
    final originalSize = t.view.physicalSize;
    final originalRatio = t.view.devicePixelRatio;
    t.view.physicalSize = const Size(1300, 400);
    t.view.devicePixelRatio = 1;
    addTearDown(() {
      t.view.physicalSize = originalSize;
      t.view.devicePixelRatio = originalRatio;
    });

    Future<(double width, int barCount)> rodWidthFor(double chartWidth) async {
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: chartWidth,
            height: 300,
            child: BarChartWidget1(
                day(), 'Thu 21 Aug', 30, const Duration(days: 1), prices: true),
          ),
        ),
      ));
      await t.pump();
      final chart = t.widget<BarChart>(find.byType(BarChart));
      final rod = chart.data.barGroups.first.barRods.first;
      return (rod.width, chart.data.barGroups.length);
    }

    final (wideWidth, wideBars) = await rodWidthFor(1100);
    final (narrowWidth, narrowBars) = await rodWidthFor(340);

    expect(wideWidth, greaterThan(narrowWidth * 3));
    // Narrower than the raw per-bar slot (a loose bound: the real slot,
    // after the reserved left axis, is smaller still).
    expect(wideWidth, lessThan(1100 / wideBars));
    expect(narrowWidth, lessThan(340 / narrowBars));
  });
}
