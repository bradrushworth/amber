import 'dart:collection';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:amber/my_theme_model.dart';
import 'package:provider/provider.dart';
import 'package:vector_math/vector_math.dart' as math;

import 'model/Usage.dart';
import 'top_section.dart';
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

  BarChartWidget1(this.rawData, this.title, this.interval, this.duration,
      {Key? key,
      this.ending = const Duration(days: 0),
      this.prices = false,
      this.forecast = false,
      this.feedIn = false})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => BarChartState();
}

class BarChartState extends State<BarChartWidget1> {
  late List<Usage>? _rawData;
  late final String _title;
  late final Duration _duration;
  late final Duration _ending;
  late final bool _prices;
  late final bool _forecast;
  late final bool _feedIn;
  int _interval = 0; // Re-synced from widget.interval on every aggregate (parseFile).
  List<BarChartGroupData> _barChartData = [];
  Map<int, String> _barChartTitles = {};
  bool _loading = true;
  bool _cancelled = false;
  bool _notEnoughData = false;

  @override
  initState() {
    super.initState();
    _rawData = widget.rawData;
    _title = widget.title;
    _duration = widget.duration;
    _ending = widget.ending;
    _prices = widget.prices;
    _forecast = widget.forecast;
    _feedIn = widget.feedIn;
    _interval = widget.interval;
    parseFile();
  }

  @override
  void didUpdateWidget(BarChartWidget1 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rawData != oldWidget.rawData) {
      //print('new didUpdateWidget _notEnoughData=$_notEnoughData _title=$_title');
      refresh(widget.rawData);
      parseFile();
    } else {
      //print('old didUpdateWidget _notEnoughData=$_notEnoughData _title=$_title');
    }
  }

  void refresh(List<Usage>? rawData) {
    setState(() {
      _rawData = rawData;
    });
  }

  @override
  Widget build(BuildContext context) {
    //print('new build');
    return Consumer<MyThemeModel>(
      builder: (context, themeModel, child) {
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
                          TopSectionWidget(
                            title: _title,
                            legends: _prices
                                ? [
                                    Legend(title: _forecast ? 'Sponge' : 'Supply', color: _forecast ? colors[7] : colors[0]),
                                    Legend(title: 'Off', color: colors[2]),
                                    Legend(title: 'Shoulder', color: colors[3]),
                                    Legend(title: 'Peak', color: colors[4]),
                                    Legend(title: 'Control', color: colors[1]),
                                    Legend(title: 'Feed', color: colors[6]),
                                  ]
                                : [
                                    Legend(title: 'Off', color: colors[2]),
                                    Legend(title: 'Shoulder', color: colors[3]),
                                    Legend(title: 'Peak', color: colors[4]),
                                    Legend(title: 'Control', color: colors[1]),
                                    Legend(title: 'Feed', color: colors[6]),
                                  ],
                            padding: const EdgeInsets.only(left: 3, right: 3, top: 3, bottom: 3),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                              child: BarChart(
                                BarChartData(
                                  barGroups: _barChartData,
                                  titlesData: FlTitlesData(
                                    rightTitles:
                                        const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    topTitles:
                                        const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                      reservedSize: 30,
                                      showTitles: true,
                                      interval: 2, // Not working anymore for some reason
                                      getTitlesWidget: (xValue, titleMeta) {
                                        return SideTitleWidget(
                                          axisSide: AxisSide.bottom,
                                          angle: math.radians(-90),
                                          space: 9,
                                          child: Text(
                                            xValue.toInt() % 2 == 0
                                                ? _barChartTitles[xValue.toInt()]!
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
                                              String formattedNumber;
                                              if (xValue < 1) {
                                                formattedNumber = xValue.toStringAsFixed(2);
                                              } else {
                                                formattedNumber = xValue.toStringAsFixed(0);
                                              }
                                              return SideTitleWidget(
                                                axisSide: AxisSide.left,
                                                //child: Text(xValue == xValue.roundToDouble() ? "$xValue" : ''),
                                                child: Text(
                                                  (_prices || _forecast ? '\$' : '') +
                                                      formattedNumber,
                                                  style: const TextStyle(fontSize: 9),
                                                ),
                                              );
                                            })),
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
      },
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
    // interval->half-hour bucketing both depend on it, so re-read the live
    // widget.interval here on every aggregate. Otherwise the first paint can
    // keep a stale 30 while the data is 5-minute: bars draw too wide and
    // every record is bucketed 30 minutes off (the bug that made toggling
    // tabs appear to 'fix' the chart).
    _interval = widget.interval;

    //final rawData = await rootBundle.loadString(filepath);
    List<Usage> data = _rawData!;
    DataAggregator dataAggregator = DataAggregator(_duration, _ending, _prices, _forecast, _feedIn, _interval,
        nowOverride: _forecast ? DateTime.now() : null);
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
  int _interval = 0; // Re-synced from widget.interval on every aggregate (parseFile).

  late final bool _today;
  late final DateTime _nowLocal;

  /// Optional injected "now". When supplied for a forecast chart, the display
  /// window is anchored on the real current day (in AEST) instead of on a
  /// record in the returned data. This makes the Yesterday/Today/Tomorrow tabs
  /// robust when the Amber API returns incomplete or unsorted future data:
  /// whatever intervals fall inside the tab's day are shown, and missing bars
  /// stay empty. Left null in unit tests to keep the data-anchored behaviour.
  final DateTime? nowOverride;

  DataAggregator(this._duration, this._ending, this._prices, this._forecast, this._feedIn, this._interval, {this.nowOverride});

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
      DateTime date = Utils.toLocal(
          DateTime.parse(record.nemTime!).subtract(Duration(minutes: _interval)));

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

      // Bars are fixed half-hour buckets (2 per hour); 5-minute data sums
      // its 6 intervals into each bar.
      int graphPos = date.hour * 2 + date.minute ~/ 30;
      newTitles[graphPos] ??= _canonicalHalfHour(graphPos);

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

      // Add the daily supply charge once per half-hour bar per day. Keyed on
      // the day + half-hour slot (not nemTime) so 5-minute sites do not add it
      // six times per bar, while multi-day charts still accrue one per day.
      String supplyKey = '${date.year}-${date.month}-${date.day}-$graphPos';
      if (_prices && !_forecast && supplyAdded.add(supplyKey)) {
        double dailySupplyChargePerPeriod = roundDouble(daily / 24 / 2, _prices);
        stackedValues[graphPos] ??= CustomRodGroup();
        stackedValues[graphPos]!.add('supply', null, null, null, dailySupplyChargePerPeriod);
      }
    }

    //print('beforeRange=$beforeRange afterRange=$afterRange');
    if (!beforeRange || !afterRange) {
      if (!_forecast) {
        // If there wasn't enough data to answer the questions
        throw NotEnoughDataException();
      }

      // Fill in any missing graph positions with zeros
      for (int graphPos = 0;
          graphPos < (24 * (60 ~/ 30));
          graphPos++) {
        //print('graphPos=$graphPos');
        stackedValues[graphPos] ??= CustomRodGroup();
        newTitles[graphPos] ??= _canonicalHalfHour(graphPos);
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

  // Canonical half-hour label for a fixed 48-bar/day chart (00:00, 00:30, ...).
  // Derived from the bar index so labels are independent of the source
  // interval length and of the intra-half-hour offset used when mapping
  // interval-end times onto bar starts (which made 5-minute sites show
  // 00:25 etc instead of 00:00/00:30).
  static String _canonicalHalfHour(int graphPos) {
    final int h = graphPos ~/ 2;
    final int m = (graphPos % 2) * 30;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  BarChartRodData makeRodData(int graphPos, CustomRodGroup stackedValues, double feedInValue) {
    double rodCumulative = 0.0;
    //int i = 0;
    int nowIndex = _nowLocal.hour * 2 + _nowLocal.minute ~/ 30;
    //print("meterNum=$meterNum");
    double value = stackedValues
        .toList()
        .map((e) => e.displayAmount(_forecast))
        .reduce((value, element) => value += element);
    return BarChartRodData(
      toY: roundDouble(value, _prices),
      color: Colors.white70,
      width: _interval == 30 ? 6 : 3, // Width of the drawn columns
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
      // Single-tariff sites return a null period; colour by descriptor so a
      // flat veryLow day renders all green rather than orange.
      if (descriptor == spike) {
        return Utils.darken(colors[4], 20); // Peak
      } else if (descriptor == high) {
        return Utils.darken(colors[4], 10); // Peak
      } else if (descriptor == neutral) {
        return colors[4]; // Peak
      } else if (descriptor == low) {
        return colors[3]; // Shoulder
      } else if (descriptor == veryLow) {
        return colors[2]; // Off peak
      } else if (descriptor == extremelyLow) {
        return Utils.lighten(colors[2], 10); // Off peak
      } else if (descriptor == negative) {
        return Utils.lighten(colors[2], 20); // Off peak
      } else {
        return colors[5]; // Unknown
      }
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

  // Usage/cost values are summed per bar; forecast prices are intensive so
  // the half-hour bar shows the average of the intervals aggregated into it.
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
