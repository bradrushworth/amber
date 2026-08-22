import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../bar_chart.dart';
import '../model/Usage.dart';
import '../state/dashboard_state.dart';
import '../state/day_math.dart';
import '../utils.dart';
import '../widgets/chart_card.dart';
import '../widgets/legend_bar.dart';
import 'day_detail.dart';

enum _Metric { cost, usage, prices }

/// Midnight AEST of the last date present in [d], as the raw instant
/// `DateTime.parse('<date>T00:00:00+10:00')` produces — the same expression
/// `DataAggregator` and `day_math` use to place their windows.
///
/// Returns null when there is nothing to anchor on yet (no slice, an empty
/// slice, or a record without a date), which the callers turn into a loading
/// placeholder row.
DateTime? _rawLastDate(List<Usage>? d) {
  if (d == null || d.isEmpty) return null;
  final date = d.last.date;
  return date == null ? null : DateTime.parse('${date}T00:00:00+10:00');
}

/// One row of the history list: either a real card backed by [data], or (when
/// [data] is null — the underlying week hasn't loaded yet) a loading
/// placeholder.
class _Entry {
  final List<Usage>? data;
  final Duration duration;
  final Duration ending;
  final String title;
  final bool allowPartial;

  /// The instant this row's window ends on, derived from [data] rather than
  /// the clock (one day past the data's last date, so it plays the role of
  /// "now" for `BarChartWidget1.anchor`). Null for loading placeholders.
  final DateTime? anchor;

  const _Entry({
    required this.data,
    required this.duration,
    required this.ending,
    required this.title,
    this.allowPartial = false,
    this.anchor,
  });

  static const loading = _Entry(
    data: null,
    duration: Duration(days: 1),
    ending: Duration.zero,
    title: 'Loading…',
  );
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

  // Memo for the concatenated current-week list, so a rebuild that changes
  // nothing doesn't hand BarChartWidget1 a fresh List identity (which would
  // re-aggregate every frame).
  List<Usage>? _currentWeekCache, _currentWeekFromWeek, _currentWeekFromToday;

  static final _dayFormat = DateFormat('E d MMM');

  /// The genuine current week: the newest completed week plus however much of
  /// today has landed. `todayUsage` is often null/empty (Amber's usage feed
  /// lags), in which case this is just `weekData[0]`.
  List<Usage>? _currentWeekData(DashboardState state) {
    final week = state.weekData[0];
    if (week == null) return null;
    final today = state.todayUsage;
    if (!identical(week, _currentWeekFromWeek) ||
        !identical(today, _currentWeekFromToday) ||
        _currentWeekCache == null) {
      _currentWeekFromWeek = week;
      _currentWeekFromToday = today;
      _currentWeekCache =
          (today == null || today.isEmpty) ? week : [...week, ...today];
    }
    return _currentWeekCache;
  }

  List<_Entry> _entries(DashboardState state) =>
      widget.weeks ? _weekEntries(state) : _dayEntries(state);

  List<_Entry> _dayEntries(DashboardState state) {
    final entries = <_Entry>[];
    for (var w = 0; w < 4; w++) {
      final weekSlice = state.weekData[w];
      // Titles are derived from the DATA's last date, never from the clock:
      // the usage endpoint routinely lags a day or more, and a clock-derived
      // title made the card claim a day the chart below it wasn't drawing.
      final raw = _rawLastDate(weekSlice);
      if (weekSlice == null || raw == null) {
        entries.add(_Entry.loading);
        continue;
      }
      final anchor = raw.add(const Duration(days: 1));
      for (var local = 0; local < 7; local++) {
        final ending = Duration(days: local);
        entries.add(_Entry(
          data: weekSlice,
          duration: const Duration(days: 1),
          ending: ending,
          title: _dayFormat.format(Utils.toLocal(raw.subtract(ending))),
          // The newest day is legitimately short (the API returns a partial
          // final day); render what there is instead of throwing
          // NotEnoughDataException and showing "Not enough data".
          allowPartial: true,
          anchor: anchor,
        ));
      }
    }
    return entries;
  }

  _Entry _weekEntry(List<Usage>? data, {bool allowPartial = false}) {
    final raw = _rawLastDate(data);
    if (data == null || raw == null) return _Entry.loading;
    return _Entry(
      data: data,
      duration: const Duration(days: 7),
      ending: Duration.zero,
      title: 'Week to ${_dayFormat.format(Utils.toLocal(raw))}',
      allowPartial: allowPartial,
      anchor: raw.add(const Duration(days: 1)),
    );
  }

  List<_Entry> _weekEntries(DashboardState state) {
    // The leading row used to re-render weekData[0] verbatim under a
    // hardcoded 'This week (partial)' title — a pixel-for-pixel duplicate of
    // the w=0 row below it. It is now a real current week (last completed
    // week + today's records so far), so it only coincides with w=0 while
    // today's usage hasn't arrived.
    final entries = <_Entry>[
      _weekEntry(_currentWeekData(state), allowPartial: true),
    ];
    for (var w = 0; w < 4; w++) {
      entries.add(_weekEntry(state.weekData[w]));
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

    // The metric belongs in the key: identical tree positions otherwise let
    // Flutter hand the same BarChartState a differently-configured widget.
    // BarChartState re-syncs everything now, but the key makes the swap a
    // fresh State and keeps the two landscape columns distinct.
    final key = ValueKey<String>(
        '${widget.weeks ? 'w' : 'd'}|${entry.title}|${entry.ending.inDays}|${metric.name}');

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
                  key: key,
                  ending: entry.ending,
                  prices: true,
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
                  key: key,
                  ending: entry.ending,
                  allowPartial: entry.allowPartial)),
        );
        break;
      case _Metric.prices:
        card = ChartCard(
          title: entry.title,
          chart: IgnorePointer(
              child: BarChartWidget1(data, entry.title, il, entry.duration,
                  key: key,
                  ending: entry.ending,
                  forecast: true,
                  prices: true,
                  allowPartial: entry.allowPartial,
                  // Forecast charts otherwise anchor on DateTime.now(); in
                  // history that made the price card show a different day
                  // from the cost/usage cards whenever the API lagged.
                  anchor: entry.anchor)),
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
          child: LegendBar(showSupply: true),
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
