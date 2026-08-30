import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../bar_chart.dart';
import '../state/dashboard_state.dart';
import '../widgets/chart_card.dart';
import '../widgets/legend_bar.dart';
import '../theme.dart';

/// The "Now" tab: a live-price hero panel (current price, period, spike
/// status, today's cost-so-far) followed by the today and tomorrow price-day
/// pairs — each pair being the buy price and the feed-in price for the same
/// day. (The yesterday pair was removed once the Days tab took over history.)
/// In landscape the two charts of a pair sit side by side, matching the old
/// two-column grid (and the History tab's paired columns).
///
/// NOTE: `LegendBar` unconditionally renders an 'Off-peak' label (see
/// lib/widgets/legend_bar.dart), which duplicates the hero sub-line's
/// 'Off-peak' period text when the current period is off-peak. Per
/// controller ruling (see task-7-report.md), the legend stays — every tab
/// gets one — and test/now_tab_test.dart's period assertion was relaxed to
/// `findsWidgets` to tolerate the duplicate.
class NowTab extends StatelessWidget {
  const NowTab({super.key});

  // The old dropdown's "Prices" group order: each day is a (label, ending)
  // pair, buy chart first, feed-in chart second.
  static const _days = [
    ('today', Duration(days: -1)),
    ('tomorrow', Duration(days: -2)),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();

    // Copied verbatim from lib/main.dart:398-405 (forecastInterval cap logic).
    int intervalLength = state.intervalLength;
    if (intervalLength < 15) intervalLength = 15;
    final int forecastInterval = intervalLength < 30 ? 30 : intervalLength;

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final priceText = state.currentPriceCents != null
        ? '${state.currentPriceCents!.toStringAsFixed(1)} c/kWh'
        : '—';

    final subLineBuffer = StringBuffer(state.currentPeriodLabel ?? '');
    if (state.isSpike) subLineBuffer.write(' · ⚡ SPIKE');
    if (state.todayCostSoFar != null) {
      subLineBuffer.write(' · today so far \$${state.todayCostSoFar!.toStringAsFixed(2)}');
    }

    Widget chart(String title, Duration ending, bool feedIn) =>
        state.forecastData == null
            ? Container(height: 180, color: AmberPalette.skeleton)
            : BarChartWidget1(
                state.forecastData,
                title,
                forecastInterval,
                const Duration(days: 1),
                ending: ending,
                forecast: true,
                prices: true,
                feedIn: feedIn,
              );

    ChartCard buyCard(String day, Duration ending) => ChartCard(
          title: 'Buy price — $day',
          chart: chart('Buy price — $day', ending, false),
        );
    ChartCard feedInCard(String day, Duration ending) => ChartCard(
          title: 'Feed-in price — $day',
          chart: chart('Feed-in price — $day', ending, true),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LegendBar(showSupply: false),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AmberPalette.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'RIGHT NOW',
                  style: TextStyle(
                    color: AmberPalette.muted,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  priceText,
                  // Mint, the way Amber's own app puts the live price in its
                  // mint circle — this number is the one thing a customer
                  // opens the app for.
                  style: const TextStyle(
                    color: AmberPalette.mint,
                    fontWeight: FontWeight.bold,
                    fontSize: 40,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subLineBuffer.toString(),
                  style: const TextStyle(color: AmberPalette.muted),
                ),
              ],
            ),
          ),
          for (final (day, ending) in _days) ...[
            const SizedBox(height: 12),
            if (isLandscape)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: buyCard(day, ending)),
                  const SizedBox(width: 12),
                  Expanded(child: feedInCard(day, ending)),
                ],
              )
            else ...[
              buyCard(day, ending),
              const SizedBox(height: 12),
              feedInCard(day, ending),
            ],
          ],
        ],
      ),
    );
  }
}
