import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../bar_chart.dart';
import '../model/Usage.dart';
import '../state/dashboard_state.dart';
import '../state/day_math.dart';
import '../widgets/chart_card.dart';
import '../widgets/legend_bar.dart';
import 'day_detail.dart';

enum _Metric { cost, usage, prices }

/// One row of the history list: either a real card backed by [data], or (when
/// [data] is null — the underlying week hasn't loaded yet) a loading
/// placeholder.
class _Entry {
  final List<Usage>? data;
  final Duration duration;
  final Duration ending;
  final String title;
  final bool allowPartial;

  const _Entry({
    required this.data,
    required this.duration,
    required this.ending,
    required this.title,
    this.allowPartial = false,
  });
}

/// The "History" tab content, shared by the Days and Weeks sub-tabs.
///
/// Portrait shows a Cost/Usage/Prices `ChoiceChip` row above a `ListView` of
/// `ChartCard`s for the selected metric. Landscape drops the chips and shows
/// side-by-side Usage/Cost columns for every row instead.
class HistoryTab extends StatefulWidget {
  final bool weeks;

  const HistoryTab({super.key, required this.weeks});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  _Metric _metric = _Metric.cost;

  List<_Entry> _entries(DashboardState state) =>
      widget.weeks ? _weekEntries(state) : _dayEntries(state);

  List<_Entry> _dayEntries(DashboardState state) {
    final now = DateTime.now();
    final entries = <_Entry>[];
    for (var w = 0; w < 4; w++) {
      final weekSlice = state.weekData[w];
      if (weekSlice == null) {
        entries.add(const _Entry(
          data: null,
          duration: Duration(days: 1),
          ending: Duration.zero,
          title: 'Loading…',
        ));
        continue;
      }
      for (var local = 0; local < 7; local++) {
        final e = w * 7 + local;
        entries.add(_Entry(
          data: weekSlice,
          duration: const Duration(days: 1),
          ending: Duration(days: local),
          title: DateFormat('E d MMM')
              .format(now.subtract(Duration(days: e + 1))),
        ));
      }
    }
    return entries;
  }

  List<_Entry> _weekEntries(DashboardState state) {
    final now = DateTime.now();
    final entries = <_Entry>[
      _Entry(
        data: state.weekData[0],
        duration: const Duration(days: 7),
        ending: Duration.zero,
        title: 'This week (partial)',
        allowPartial: true,
      ),
    ];
    for (var w = 0; w < 4; w++) {
      entries.add(_Entry(
        data: state.weekData[w],
        duration: const Duration(days: 7),
        ending: Duration.zero,
        title:
            'Week to ${DateFormat('E d MMM').format(now.subtract(Duration(days: w * 7 + 1)))}',
      ));
    }
    return entries;
  }

  Widget _cardFor(
      BuildContext context, _Entry entry, _Metric metric, int intervalLength) {
    final data = entry.data;
    if (data == null) {
      return const ChartCard(
        title: 'Loading…',
        chart: SizedBox(
          height: 180,
          child: ColoredBox(color: Color(0xFF23232F)),
        ),
      );
    }

    // Historical charts cap interval at 15 (mirror of old main.dart).
    final il = intervalLength < 15 ? 15 : intervalLength;

    final Widget card;
    switch (metric) {
      case _Metric.cost:
        final value =
            sumForRange(data, entry.duration, entry.ending, cost: true);
        card = ChartCard(
          title: entry.title,
          trailing: '\$${value.toStringAsFixed(2)}',
          chart: IgnorePointer(
              child: BarChartWidget1(data, entry.title, il, entry.duration,
                  ending: entry.ending,
                  prices: true,
                  showHeader: false,
                  yUnit: '\$',
                  allowPartial: entry.allowPartial)),
        );
        break;
      case _Metric.usage:
        final value =
            sumForRange(data, entry.duration, entry.ending, cost: false);
        card = ChartCard(
          title: entry.title,
          trailing: '${value.toStringAsFixed(1)} kWh',
          chart: IgnorePointer(
              child: BarChartWidget1(data, entry.title, il, entry.duration,
                  ending: entry.ending,
                  showHeader: false,
                  yUnit: 'kWh',
                  allowPartial: entry.allowPartial)),
        );
        break;
      case _Metric.prices:
        card = ChartCard(
          title: entry.title,
          chart: IgnorePointer(
              child: BarChartWidget1(data, entry.title, il, entry.duration,
                  ending: entry.ending,
                  forecast: true,
                  prices: true,
                  showHeader: false,
                  yUnit: 'c',
                  allowPartial: entry.allowPartial)),
        );
        break;
    }

    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => DayDetail(
              title: entry.title,
              data: data,
              duration: entry.duration,
              ending: entry.ending,
              interval: il))),
      child: card,
    );
  }

  Widget _chipsRow() {
    const labels = {
      _Metric.cost: 'Cost',
      _Metric.usage: 'Usage',
      _Metric.prices: 'Prices',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Wrap(
        spacing: 8,
        children: _Metric.values
            .map((m) => ChoiceChip(
                  label: Text(labels[m]!),
                  selected: _metric == m,
                  onSelected: (_) => setState(() => _metric = m),
                ))
            .toList(),
      ),
    );
  }

  Widget _landscapeHeader() {
    const style = TextStyle(
      color: Color(0xFF9595A4),
      fontWeight: FontWeight.bold,
      fontSize: 12,
      letterSpacing: 1.2,
    );
    return const Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          Expanded(child: Text('USAGE (kWh)', style: style)),
          Expanded(child: Text('COST (\$)', style: style)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    final il = state.intervalLength;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final entries = _entries(state);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: LegendBar(showSupply: true, showPrices: false),
        ),
        if (!isLandscape) _chipsRow(),
        if (isLandscape) _landscapeHeader(),
        Expanded(
          child: isLandscape
              ? ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          child: _cardFor(
                              context, entries[i], _Metric.usage, il)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _cardFor(
                              context, entries[i], _Metric.cost, il)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) =>
                      _cardFor(context, entries[i], _metric, il),
                ),
        ),
      ],
    );
  }
}
