import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../bar_chart.dart';
import '../state/dashboard_state.dart';
import '../widgets/chart_card.dart';
import '../widgets/legend_bar.dart';

/// The "Now" tab: a live-price hero panel (current price, period, spike
/// status, today's cost-so-far, and a headerless today buy-price chart)
/// followed by yesterday/tomorrow buy and feed-in price cards.
///
/// NOTE: `LegendBar` unconditionally renders an 'Off-peak' label (see
/// lib/widgets/legend_bar.dart), which duplicates the hero sub-line's
/// 'Off-peak' period text when the current period is off-peak. Per
/// controller ruling (see task-7-report.md), the legend stays — every tab
/// gets one — and test/now_tab_test.dart's period assertion was relaxed to
/// `findsWidgets` to tolerate the duplicate.
class NowTab extends StatelessWidget {
  const NowTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();

    // Copied verbatim from lib/main.dart:398-405 (forecastInterval cap logic).
    int intervalLength = state.intervalLength;
    if (intervalLength < 15) intervalLength = 15;
    final int forecastInterval = intervalLength < 30 ? 30 : intervalLength;

    final priceText = state.currentPriceCents != null
        ? '${state.currentPriceCents!.toStringAsFixed(1)} c/kWh'
        : '—';

    final subLineBuffer = StringBuffer(state.currentPeriodLabel ?? '');
    if (state.isSpike) subLineBuffer.write(' · ⚡ SPIKE');
    if (state.todayCostSoFar != null) {
      subLineBuffer.write(' · today so far \$${state.todayCostSoFar!.toStringAsFixed(2)}');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LegendBar(showSupply: false),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A26),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'RIGHT NOW',
                  style: TextStyle(
                    color: Color(0xFF9595A4),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  priceText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 40,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subLineBuffer.toString(),
                  style: const TextStyle(color: Color(0xFF9595A4)),
                ),
                const SizedBox(height: 12),
                state.forecastData == null
                    ? Container(height: 180, color: const Color(0xFF23232F))
                    : SizedBox(
                        height: 180,
                        child: BarChartWidget1(
                          state.forecastData,
                          'today',
                          forecastInterval,
                          const Duration(days: 1),
                          ending: const Duration(days: -1),
                          forecast: true,
                          prices: true,
                          yUnit: 'c',
                        ),
                      ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ChartCard(
            title: 'Buy price — yesterday',
            chart: state.forecastData == null
                ? Container(height: 180, color: const Color(0xFF23232F))
                : BarChartWidget1(
                    state.forecastData,
                    'Buy price — yesterday',
                    forecastInterval,
                    const Duration(days: 1),
                    ending: const Duration(days: 0),
                    forecast: true,
                    prices: true,
                    feedIn: false,
                  ),
          ),
          const SizedBox(height: 12),
          ChartCard(
            title: 'Feed-in price — yesterday',
            chart: state.forecastData == null
                ? Container(height: 180, color: const Color(0xFF23232F))
                : BarChartWidget1(
                    state.forecastData,
                    'Feed-in price — yesterday',
                    forecastInterval,
                    const Duration(days: 1),
                    ending: const Duration(days: 0),
                    forecast: true,
                    prices: true,
                    feedIn: true,
                  ),
          ),
          const SizedBox(height: 12),
          ChartCard(
            title: 'Buy price — tomorrow',
            chart: state.forecastData == null
                ? Container(height: 180, color: const Color(0xFF23232F))
                : BarChartWidget1(
                    state.forecastData,
                    'Buy price — tomorrow',
                    forecastInterval,
                    const Duration(days: 1),
                    ending: const Duration(days: -2),
                    forecast: true,
                    prices: true,
                    feedIn: false,
                  ),
          ),
          const SizedBox(height: 12),
          ChartCard(
            title: 'Feed-in price — tomorrow',
            chart: state.forecastData == null
                ? Container(height: 180, color: const Color(0xFF23232F))
                : BarChartWidget1(
                    state.forecastData,
                    'Feed-in price — tomorrow',
                    forecastInterval,
                    const Duration(days: 1),
                    ending: const Duration(days: -2),
                    forecast: true,
                    prices: true,
                    feedIn: true,
                  ),
          ),
        ],
      ),
    );
  }
}
