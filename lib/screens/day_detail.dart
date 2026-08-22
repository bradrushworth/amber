import 'package:flutter/material.dart';

import '../bar_chart.dart';
import '../model/Usage.dart';
import '../state/day_math.dart';

/// Full-screen detail for a single day/week: a full-height cost chart above
/// a row of DAY TOTAL / USED / FEED-IN stat tiles, reached by tapping a
/// history `ChartCard`.
class DayDetail extends StatelessWidget {
  final String title;
  final List<Usage> data;
  final Duration duration;
  final Duration ending;
  final int interval;

  const DayDetail({
    super.key,
    required this.title,
    required this.data,
    required this.duration,
    required this.ending,
    required this.interval,
  });

  Widget _statTile(String label, String value) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF23232F),
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF9595A4),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dayTotal = sumForRange(data, duration, ending, cost: true);
    final used = sumForRange(data, duration, ending, cost: false);
    final feedIn = sumFeedIn(data, duration, ending);

    return Scaffold(
      backgroundColor: const Color(0xFF20202A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A26),
        title: Text(title),
      ),
      body: Column(
        children: [
          Expanded(
            child: BarChartWidget1(data, title, interval, duration,
                ending: ending,
                prices: true,
                yUnit: '\$',
                allowPartial: true),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _statTile('DAY TOTAL', '\$${dayTotal.toStringAsFixed(2)}'),
                const SizedBox(width: 8),
                _statTile('USED', '${used.toStringAsFixed(1)} kWh'),
                const SizedBox(width: 8),
                _statTile('FEED-IN', '\$${feedIn.toStringAsFixed(2)}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
