import 'dart:collection';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'model/Usage.dart';
import 'utils.dart';

const int meterInterval = 30; // minutes
const double daily = 0.5677 + 1.57; // Daily charge

const String controlledLoad = 'controlledLoad';
const String general = 'general';
const String feedIn = 'feedIn';
const String supply = 'supply';
const String peak = 'peak';
const String shoulder = 'shoulder';
const String offPeak = 'offPeak';
const String solarSponge = 'solarSponge';

const String negative = 'negative';
const String extremelyLow = 'extremelyLow';
const String veryLow = 'veryLow';
const String low = 'low';
const String neutral = 'neutral';
const String high = 'high';
const String spike = 'spike';

final List<Color> colors = [
  const Color(0xFF5974FF),
  const Color(0xFFFF3E8D),
  Colors.lightGreen,
  Colors.orange,
  Colors.red,
  Colors.blueAccent,
  Colors.yellowAccent,
  Colors.cyan, // solarSponge (distinct from off-peak green)
];

class BarChartWidget1 extends StatefulWidget {
  late List<Usage>? rawData;
  late String title;
  late Duration duration;
  late Duration ending;
  final bool prices;
  final bool forecast;
  final bool feedIn;
  final int interval;
  final bool allowPartial;

  /// Optional injected "now", forwarded to [DataAggregator.nowOverride].
  ///
  /// When null the previous behaviour applies: forecast charts anchor on the
  /// real clock (`DateTime.now()`), everything else anchors on the last date
  /// present in [rawData]. Supplying an anchor lets a caller (the history
  /// feed) pin BOTH kinds of chart to the same data-derived instant, so the
  /// card title, the drawn window and the trailing total can't drift apart
  /// when the Amber usage API lags a day or two behind the wall clock.
  final DateTime? anchor;

  BarChartWidget1(this.rawData, this.title, this.interval, this.duration,
      {Key? key,
      this.ending = const Duration(days: 0),
      this.prices = false,
      this.forecast = false,
      this.feedIn = false,
      this.allowPartial = false,
      this.anchor})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => BarChartState();
}

class BarChartState extends State<BarChartWidget1> {
  // NONE of these may be `late final`. Flutter reuses a State object whenever
  // the new widget has the same runtimeType and key at the same tree position,
  // so a Cost -> Usage metric switch in the history feed hands this State a
  // brand-new BarChartWidget1 with different flags. Caching the first widget's
  // values in final fields made the chart keep drawing its first metric for
  // ever (only the card's title/trailing text changed). See _syncFromWidget.
  // (Plain defaults rather than `late`: _syncFromWidget reads them to detect
  // a change, and it runs for the first time from initState.)
  List<Usage>? _rawData;
  String _title = '';
  Duration _duration = Duration.zero;
  Duration _ending = Duration.zero;
  bool _prices = false;
  bool _forecast = false;
  bool _feedIn = false;
  bool _allowPartial = false;
  DateTime? _anchor;
  int _interval = 0; // Re-synced from widget.interval on every aggregate (parseFile).
  List<BarChartGroupData> _barChartData = [];
  Map<int, String> _barChartTitles = {};
  bool _loading = true;
  bool _cancelled = false;
  bool _notEnoughData = false;

  @override
  initState() {
    super.initState();
    _syncFromWidget();
    parseFile();
  }

  /// Copy every rendering input off the current widget. Returns true when any
  /// of them actually changed, i.e. when the cached aggregation is stale.
  bool _syncFromWidget() {
    final changed = _rawData != widget.rawData ||
        _title != widget.title ||
        _duration != widget.duration ||
        _ending != widget.ending ||
        _prices != widget.prices ||
        _forecast != widget.forecast ||
        _feedIn != widget.feedIn ||
        _allowPartial != widget.allowPartial ||
        _anchor != widget.anchor ||
        _interval != widget.interval;
    _rawData = widget.rawData;
    _title = widget.title;
    _duration = widget.duration;
    _ending = widget.ending;
    _prices = widget.prices;
    _forecast = widget.forecast;
    _feedIn = widget.feedIn;
    _allowPartial = widget.allowPartial;
    _anchor = widget.anchor;
    _interval = widget.interval;
    return changed;
  }

  @override
  void didUpdateWidget(BarChartWidget1 oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-sync EVERY input (not just rawData/interval) and re-aggregate when
    // anything moved: the history feed's metric chips swap prices/forecast on
    // a reused State, and the window params can change with the data.
    if (_syncFromWidget()) {
      parseFile();
    }
  }

  @override
  Widget build(BuildContext context) {
    //print('new build');
    // The per-card title/legend header (TopSectionWidget) was deleted in the
    // UI overhaul: titles now live on ChartCard and the legend is a single
    // LegendBar per tab.
    return Column(
      children: _loading
          ? [
              const Spacer(),
              Text(
                'Data is loading for:\n$_title',
                textAlign: TextAlign.center,
              ),
              const Spacer()
            ]
          : _cancelled
              ? [
                  const Spacer(),
                  Text(
                    'No API key entered yet:\n$_title',
                    textAlign: TextAlign.center,
                  ),
                  const Spacer()
                ]
              : _notEnoughData
                  ? [
                      const Spacer(),
                      Text(
                        'Not enough data available for:\n$_title',
                        textAlign: TextAlign.center,
                      ),
                      const Spacer()
                    ]
                  : [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                          child: BarChart(
                            BarChartData(
                              barGroups: _barChartData,
                              groupsSpace: _interval == 5 ? 1 : (_interval == 15 ? 2 : 3), // Match width: narrower spacing for 5-min data
                              titlesData: FlTitlesData(
                                rightTitles:
                                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles:
                                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                  reservedSize: 30,
                                  showTitles: true,
                                  interval: (60 ~/ _interval).toDouble(), // one label per hour (2/4/12 bars for 30/15/5-min)
                                  getTitlesWidget: (xValue, titleMeta) {
                                    int graphPos = xValue.toInt();
                                    return SideTitleWidget(
                                      axisSide: AxisSide.bottom,
                                      angle: 0,
                                      space: 9,
                                      child: Text(
                                        graphPos % (3 * (60 ~/ _interval)) == 0
                                            ? _barChartTitles[graphPos]!
                                            : '',
                                        // Workaround
                                        style: const TextStyle(fontSize: 8),
                                      ),
                                    );
                                  },
                                )),
                                leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                        showTitles: true,
                                        //interval: 1,
                                        reservedSize: 40,
                                        getTitlesWidget: (xValue, titleMeta) {
                                          // fl_chart adds the axis min/max on top of its evenly spaced
                                          // ticks (AxisChartHelper.iterateThroughAxis); on a short card
                                          // that extra label lands on the neighbouring tick ('$0.42'
                                          // printed over '$0.40'). Keep the even ticks, drop an edge
                                          // label that isn't on one.
                                          final double step = titleMeta.appliedInterval;
                                          if (step > 0 &&
                                              (xValue == titleMeta.min || xValue == titleMeta.max) &&
                                              ((xValue / step) - (xValue / step).round()).abs() > 1e-6) {
                                            return const SizedBox.shrink();
                                          }
                                          // -0.0 would format as '-0.00'.
                                          if (xValue == 0) xValue = 0;
                                          String formattedNumber = titleMeta.max < 1
                                              ? xValue.toStringAsFixed(2)
                                              : xValue.toStringAsFixed(1);
                                          return SideTitleWidget(
                                            axisSide: AxisSide.left,
                                            //child: Text(xValue == xValue.roundToDouble() ? "$xValue" : ''),
                                            child: Text(
                                              // The unit is derived here and
                                              // ONLY here: a caller-supplied
                                              // yUnit used to be appended on
                                              // top of this prefix, printing
                                              // '$0.50$' / '$0.20c'.
                                              _prices || _forecast
                                                  ? '\$$formattedNumber'
                                                  : '$formattedNumber kWh',
                                              style: const TextStyle(fontSize: 9),
                                            ),
                                          );
                                        })),
                              ),
                              barTouchData: BarTouchData(
                                enabled: true,
                                handleBuiltInTouches: true,
                                touchTooltipData: BarTouchTooltipData(
                                  getTooltipItem: (group, gi, rod, ri) {
                                    final label = _barChartTitles[group.x] ?? '';
                                    // Forecast bars are a price per unit of
                                    // energy, not a dollar amount. Currency reads
                                    // as a prefix ('$0.18'), not the trailing
                                    // '0.18 $' this used to print.
                                    final value = rod.toY
                                        .toStringAsFixed(_prices || _forecast ? 2 : 3);
                                    final amount = _forecast
                                        ? '\$$value/kWh'
                                        : (_prices ? '\$$value' : '$value kWh');
                                    return BarTooltipItem(
                                        '$label\n$amount',
                                        const TextStyle(color: Colors.white, fontSize: 11));
                                  },
                                ),
                              ),
                              //maxY: 10.0,
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                            ),
                            duration:
                                Duration.zero, // Duration(milliseconds: 1500)
                          ),
                        ),
                      ),
                    ],
    );
  }

  void parseFile() {
    if (_rawData == null) {
      setState(() {
        _barChartData = [];
        _barChartTitles = {};
        _loading = false;
        _cancelled = true;
        _notEnoughData = false;
      });
      return;
    }
    if (_rawData!.isEmpty) {
      setState(() {
        _barChartData = [];
        _barChartTitles = {};
        _loading = true;
        _cancelled = false;
        _notEnoughData = false;
      });
      return;
    }

    // The selected site's meter interval can change after the first paint
    // (e.g. a different site is selected, or the default 30 is corrected to 5
    // once the site list loads / _getForecast runs). Bar width and the
    // interval->bar bucketing both depend on it, so re-read the live
    // widget.interval here on every aggregate. Otherwise the first paint can
    // keep a stale 30 while the data is 5-minute: bars draw too wide and
    // every record is bucketed 30 minutes off (the bug that made toggling
    // tabs appear to 'fix' the chart).
    _interval = widget.interval;

    //final rawData = await rootBundle.loadString(filepath);
    List<Usage> data = _rawData!;
    // An explicit anchor wins; otherwise forecast charts follow the clock and
    // historical charts stay anchored on their own data (nowOverride null).
    DataAggregator dataAggregator = DataAggregator(_duration, _ending, _prices, _forecast, _feedIn, _interval,
        nowOverride: _anchor ?? (_forecast ? DateTime.now() : null),
        allowPartial: _allowPartial);
    try {
      dataAggregator.aggregateData(data);

      setState(() {
        _barChartData = dataAggregator.newData.values.toList();
        _barChartTitles = dataAggregator.newTitles;
        _loading = false;
        _cancelled = false;
        _notEnoughData = false;
      });
      //print('Data updated successfully!');
    } on NotEnoughDataException {
      // Data exists but not enough for this particular chart
      //print('NotEnoughDataException!');

      setState(() {
        _barChartData = [];
        _barChartTitles = {};
        _loading = false;
        _cancelled = false;
        _notEnoughData = true;
      });
    }
  }
}

class DataAggregator {
  final SplayTreeMap<int, BarChartGroupData> newData = SplayTreeMap<int, BarChartGroupData>();
  final SplayTreeMap<int, String> newTitles = SplayTreeMap<int, String>();

  late final Duration _duration, _ending;
  late final bool _prices;
  late final bool _forecast;
  late final bool _feedIn;
  late final bool _allowPartial;
  int _interval = 0; // Re-synced from widget.interval on every aggregate (parseFile).

  late final bool _today;
  late final DateTime _nowLocal;

  /// Optional injected "now". When supplied for a forecast chart, the display
  /// window is anchored on the real current day (in AEST) instead of on a
  /// record in the returned data. This makes the Yesterday/Today/Tomorrow tabs
  /// robust when the Amber API returns incomplete or unsorted future data:
  /// whatever intervals fall inside the tab's day are shown, and missing bars
  /// stay empty. Left null in unit tests to keep the data-anchored behaviour.
  ///
  /// The history feed passes a DATA-derived instant here (see
  /// `BarChartWidget1.anchor`) so its forecast/price charts line up with the
  /// data-anchored cost/usage charts beside them instead of following the
  /// wall clock.
  final DateTime? nowOverride;

  DataAggregator(this._duration, this._ending, this._prices, this._forecast, this._feedIn, this._interval, {this.nowOverride, bool allowPartial = false}) : _allowPartial = allowPartial;

  void aggregateData(List<Usage> data) {
    //print(data.map((u) => u.channelType!).toSet());

    //print('data.last.date=${data.last.date}');
    //print('data.first.date=${data.first.date}');
    // For forecast tabs, anchor the window on the real current day (AEST) so
    // incomplete/unsorted future data still shows whatever we received. For
    // historical charts (and forecast unit tests without an injected now),
    // keep anchoring on the most recent day present in the data.
    late DateTime latest;
    if (_forecast && nowOverride != null) {
      final DateTime aestNow = Utils.toLocal(nowOverride!);
      final DateTime todayMidnight =
          DateTime.utc(aestNow.year, aestNow.month, aestNow.day);
      latest = todayMidnight.subtract(_ending);
    } else {
      latest = Utils.toLocal(DateTime.parse('${data.last.date!}T00:00:00+10:00')
          .subtract(_ending)
          .add(const Duration(days: 1)));
    }
    DateTime earliest = latest.subtract(_duration);
    // Q1: bars are per-interval buckets. A 30-min site still shows 48
    // half-hour bars; a 5-min site shows 288 five-minute bars. graphPos
    // identifies the interval slot (one bar per interval for a single day)
    // while multi-day charts still collapse into one canonical day because
    // graphPos ignores the calendar day. Bucketing (sum usage/cost, average
    // forecast) is unchanged and is what makes Combined Days / Weekly Usage work.
    final int periodsPerHour = 60 ~/ _interval;
    final int barsPerDay = 24 * periodsPerHour;
    //print('latest=$latest earliest=$earliest');

    _nowLocal = Utils.toLocal(nowOverride ?? DateTime.now());
    _today = _nowLocal.isAfter(earliest) && _nowLocal.isBefore(latest);

    Map<int, CustomRodGroup> stackedValues = {};
    Map<int, double> feedInValue = {};
    Map<int, int> feedInCount = {};
    Set<String> supplyAdded = {};

    bool beforeRange = false;
    bool afterRange = false;
    bool hasControlled = false;

    // Have a look if the controlled load is in the data somewhere
    for (int n = 0; n < data.length; n++) {
      Usage record = data[n];
      if (record.channelType == controlledLoad) {
        hasControlled = true;
        break;
      }
    }

    // Start drawing the data
    for (int n = 0; n < data.length; n++) {
      Usage record = data[n];

      //print("adding record=" + record.nemTime!);
      // nemTime is the END of the interval, so the interval STARTS at nemTime
      // minus the RECORD's own length -- not minus the chart's bar width. The
      // two differ whenever a site's records are finer than the bars drawn
      // from them: the Now tab requests resolution=<site interval> (5 minutes
      // here) and draws 30-minute bars, so subtracting 30 pushed five of every
      // six readings into the previous half hour and a cheap 06:30 rendered at
      // the expensive 07:00 price.
      DateTime date = Utils.toLocal(DateTime.parse(record.nemTime!)
          .subtract(Duration(minutes: record.duration ?? _interval)));

      if (date.isBefore(earliest)) {
        continue; // Skip data outside of range
      }
      if (date.isAtSameMomentAs(earliest)) {
        beforeRange = true;
      }
      if (date.isAtSameMomentAs(latest.subtract(Duration(minutes: _interval)))) {
        afterRange = true;
      }
      if (date.isAfter(latest) || date.isAtSameMomentAs(latest)) {
        continue; // Skip data outside of range
      }
      //print('Allowed date=$date');

      // Bars are fixed per-interval buckets (periodsPerHour per hour): a 30-min
      // site shows 48 half-hour bars; a 5-min site shows 288 five-minute bars.
      int graphPos = date.hour * periodsPerHour + date.minute ~/ _interval;
      newTitles[graphPos] ??= _canonicalHalfHour(graphPos, _interval);

      //print("adding record channel");
      if (record.channelType == controlledLoad && _forecast && !_feedIn) {
        // Skip the controlled load when forecasting
        continue;
      } else if (record.channelType == general && _forecast && _feedIn) {
        // Skip the general load when forecasting the feedIn graph
        continue;
      } else if (record.channelType != feedIn &&
          ((_forecast && record.perKwh != null) ||
              (_prices && record.cost != null && record.cost! >= 0.0) ||
              (!_prices && record.kwh != null && record.kwh! >= 0.0))) {
        // Record if a controlledLoad exists, and reverse the cost chart
        // positivity/negativity for usability if there is not one
        if (record.channelType == controlledLoad) {
          hasControlled = true;
        }
        // Ignore feed in tariff here or negative costs. Forecast charts show
        // the price (perKwh); usage/cost charts sum kwh/cost.
        stackedValues[graphPos] ??= CustomRodGroup();
        stackedValues[graphPos]!.add(
            record.channelType!,
            record.tariffInformation?.demandWindow,
            record.tariffInformation?.period,
            record.descriptor,
            roundDouble(
                _prices || _forecast
                    ? (_forecast ? record.perKwh! : (record.cost ?? record.perKwh!)) / 100
                    : record.kwh ?? record.perKwh! / 100,
                _prices || _forecast));
      } else if ((_feedIn && record.channelType == feedIn) ||
          (_feedIn && record.perKwh != null) ||
          (_prices && record.cost != null) ||
          (!_prices && record.kwh != null)) {
        // Calculate feed in tariff
        stackedValues[graphPos] ??= CustomRodGroup();
        if (_forecast && _prices && !hasControlled) {
          stackedValues[graphPos]!.add(
              record.channelType!,
              record.tariffInformation?.demandWindow,
              record.tariffInformation?.period,
              record.descriptor,
              roundDouble(
                  -(_prices || _forecast
                      ? (_forecast ? record.perKwh! : (record.cost ?? record.perKwh!)) / 100
                      : (record.kwh ?? record.perKwh! / 100)),
                  _prices || _forecast));
        } else {
          feedInValue[graphPos] = (feedInValue[graphPos] ?? 0.0) +
              roundDouble(
                  _prices || _forecast
                      ? (_forecast ? record.perKwh! : (record.cost ?? record.perKwh!)) / 100
                      : -(record.kwh ?? record.perKwh! / 100),
                  _prices || _forecast);
          feedInCount[graphPos] = (feedInCount[graphPos] ?? 0) + 1;
        }
      } else {
        //print("unmatched record");
      }

      // Add the daily supply charge once per bar per day. Keyed on
      // the day + slot (not nemTime) so multi-day charts accrue one charge per
      // day per slot and a single-interval bar never double-counts.
      String supplyKey = '${date.year}-${date.month}-${date.day}-$graphPos';
      if (_prices && !_forecast && supplyAdded.add(supplyKey)) {
        // Split across the actual number of bars per day so the per-day total
        // is always `daily` (a fixed /48 doubled the charge on 15-minute bars).
        // Not pre-rounded: cent-rounding a tiny per-bar fraction distorts the
        // daily total; display rounding happens in makeRodData.
        double dailySupplyChargePerPeriod = daily / barsPerDay;
        stackedValues[graphPos] ??= CustomRodGroup();
        stackedValues[graphPos]!.add('supply', null, null, null, dailySupplyChargePerPeriod);
      }
    }

    //print('beforeRange=$beforeRange afterRange=$afterRange');
    if (!beforeRange || !afterRange) {
      if (!_forecast && !_allowPartial) {
        // If there wasn't enough data to answer the questions
        throw NotEnoughDataException();
      }

      // Fill in any missing graph positions with zeros
      for (int graphPos = 0;
          graphPos < barsPerDay;
          graphPos++) {
        //print('graphPos=$graphPos');
        stackedValues[graphPos] ??= CustomRodGroup();
        newTitles[graphPos] ??= _canonicalHalfHour(graphPos, _interval);
      }
    }

    for (int graphPos in stackedValues.keys) {
      //print("feedInValue=$feedInValue");
      //print("saving graphPos=$graphPos record[1]=${stackedValue[graphPos]}");
      newData[graphPos] = BarChartGroupData(
          x: graphPos,
          barRods: [
            makeRodData(
                graphPos,
                stackedValues[graphPos]!,
                _forecast && (feedInCount[graphPos] ?? 0) > 0
                    ? (feedInValue[graphPos] ?? 0.0) / feedInCount[graphPos]!
                    : (feedInValue[graphPos] ?? 0.0))
          ]);
    }
  }

  static double roundDouble(num value, bool prices) {
    int digits = prices ? 2 : 3;
    num mod = pow(10.0, digits);
    double result = ((value * mod).roundToDouble() / mod);
    return result;
  }

  // Canonical per-interval label (00:00, 00:05, 00:30, ...), derived from
  // the bar index so labels track the meter interval.
  // Derived from the bar index so labels are independent of the source
  // interval length and of the intra-half-hour offset used when mapping
  // interval-end times onto bar starts (which made 5-minute sites show
  // 00:25 etc instead of 00:00/00:30).
  static String _canonicalHalfHour(int graphPos, int interval) {
    final int slotsPerHour = 60 ~/ interval;
    final int h = graphPos ~/ slotsPerHour;
    final int m = (graphPos % slotsPerHour) * interval;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  BarChartRodData makeRodData(int graphPos, CustomRodGroup stackedValues, double feedInValue) {
    double rodCumulative = 0.0;
    //int i = 0;
    final int periodsPerHour = 60 ~/ _interval;
    int nowIndex = _nowLocal.hour * periodsPerHour + _nowLocal.minute ~/ _interval;
    //print("meterNum=$meterNum");
    double value = stackedValues
        .toList()
        .map((e) => e.displayAmount(_forecast))
        .reduce((value, element) => value += element);
    return BarChartRodData(
      toY: roundDouble(value, _prices),
      // Transparent, not a colour: the rod is only a backdrop for
      // `rodStackItems`, which carry every visible segment. A solid rod
      // showed through above the stack as a grey tip.
      color: Colors.transparent,
      width: _interval == 5 ? 2 : (_interval == 15 ? 4 : 7), // Narrower bars for 5-min data (6 intervals aggregated per bar), wider for 30-min
      //borderRadius: BorderRadius.circular(2),
      rodStackItems: stackedValues
          .toList()
          .map((e) => BarChartRodStackItem(
              rodCumulative,
              rodCumulative += roundDouble(e.displayAmount(_forecast), _prices),
              _today && graphPos == nowIndex
                  ? Utils.lighten(e.getCostColor(), 75)
                  : e.getCostColor()))
          .toList(),
      backDrawRodData: BackgroundBarChartRodData(
        show: true,
        toY: feedInValue,
        color: colors[6],
      ),
    );
  }
}

class NotEnoughDataException implements Exception {}

class CustomRodElement {
  double amount = 0.0;
  int count = 0;
  String channelType;
  bool demandWindow = false;
  String? tariffInformation;
  String? descriptor;

  CustomRodElement(this.channelType);

  Color getCostColor() {
    if (channelType == controlledLoad) {
      return colors[1]; // Controlled
    } else if (channelType == feedIn) {
      return colors[6]; // Feed In
    } else if (channelType == supply) {
      return colors[0]; // Supply
    } else if (tariffInformation != null) {
      if (tariffInformation == peak || demandWindow) {
        return colors[4]; // Peak
      } else if (tariffInformation == shoulder) {
        return colors[3]; // Shoulder
      } else if (tariffInformation == offPeak) {
        return colors[2]; // Off peak
      } else if (tariffInformation == solarSponge) {
        return colors[7]; // Solar sponge (distinct from off-peak green)
      } else {
        return colors[5]; // Unknown
      }
    } else {
      // Single-tariff / flat-tariff sites return a null period and a single,
      // flat price, so every interval is off-peak priced. Render the whole day
      // green (off-peak) - never orange/shoulder (which a 'low' descriptor used
      // to wrongly map to) or red/peak - so a flat site is uniformly green.
        return colors[2]; // Off peak
    }
  }

  void setDemandWindow(bool? demandWindow) {
    if (demandWindow != null) this.demandWindow = demandWindow;
  }

  void setTariffInformation(String? tariffInformation) {
    if (tariffInformation != null) this.tariffInformation = tariffInformation;
  }

  void setDescriptor(String? descriptor) {
    if (descriptor != null) this.descriptor = descriptor;
  }

  void add(num num) {
    amount += num;
    count++;
  }

  // Usage/cost values are summed across the intervals in a bar; forecast prices
  // are intensive, so a multi-interval bar shows their average (under Q1 each bar holds one interval).
  double displayAmount(bool forecast) => forecast && count > 0 ? amount / count : amount;
}

class CustomRodGroup {
  CustomRodElement supplyElement = CustomRodElement(supply);
  CustomRodElement controlledElement = CustomRodElement(controlledLoad);
  CustomRodElement generalElement = CustomRodElement(general);
  CustomRodElement feedInElement = CustomRodElement(feedIn);

  CustomRodGroup();

  void add(String channelType, bool? demandWindow, String? tariffInformation, String? descriptor,
      num num) {
    if (channelType == controlledLoad) {
      controlledElement.add(num);
    } else if (channelType == feedIn) {
      feedInElement.add(num);
    } else if (channelType == supply) {
      supplyElement.add(num);
    } else if (channelType == general) {
      generalElement.setDemandWindow(demandWindow);
      generalElement.setTariffInformation(tariffInformation);
      generalElement.setDescriptor(descriptor);
      generalElement.add(num);
    } else {
      throw Exception('Unknown channel type! {$channelType}');
    }
  }

  List<CustomRodElement> toList() {
    return [supplyElement, generalElement, controlledElement, feedInElement];
  }
}
