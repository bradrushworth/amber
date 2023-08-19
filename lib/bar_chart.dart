import 'dart:collection';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:amber/my_theme_model.dart';
import 'package:provider/provider.dart';
import 'package:vector_math/vector_math.dart' as math;

import 'model/Usage.dart';
import 'top_section.dart';

// const String cancelled = 'Cancelled';
// const String loading = 'Loading';

const int METER_INTERVAL = 30; // minutes
const double DAILY = 19.00 * 12 / 365; // Daily charge

final List<Color> colors = [
  const Color(0xFF5974FF),
  const Color(0xFFFF3E8D),
  Colors.lightGreen,
  Colors.orange,
  Colors.red,
  Colors.blueAccent,
  Colors.yellowAccent,
];

class BarChartWidget1 extends StatefulWidget {
  late List<Usage>? rawData;
  late String title;
  late final Duration duration;
  late final Duration ending;
  bool prices;

  BarChartWidget1(this.rawData, this.title, this.duration,
      {Key? key, this.ending = const Duration(days: 0), this.prices = false})
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
                                    Legend(title: 'Off', color: colors[2]),
                                    Legend(title: 'Shoulder', color: colors[3]),
                                    Legend(title: 'Peak', color: colors[4]),
                                    Legend(title: 'Control', color: colors[1]),
                                    Legend(title: 'Feed', color: colors[6]),
                                    Legend(title: 'Amber', color: colors[0]),
                                  ]
                                : [
                                    Legend(title: 'Off', color: colors[2]),
                                    Legend(title: 'Shoulder', color: colors[3]),
                                    Legend(title: 'Peak', color: colors[4]),
                                    Legend(title: 'Feed', color: colors[6]),
                                    Legend(title: 'Control', color: colors[1]),
                                  ],
                            padding: const EdgeInsets.only(left: 3, right: 3, top: 3, bottom: 3),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                              child: BarChart(
                                BarChartData(
                                  barGroups: _barChartData,
                                  //[BarChartGroupData(x: 0, barRods: [makeRodData(80)]),],
                                  titlesData: FlTitlesData(
                                    rightTitles:
                                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    topTitles:
                                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                      reservedSize: 30,
                                      showTitles: true,
                                      interval: 2, // Not working anymore for some reason
                                      getTitlesWidget: (xValue, titleMeta) {
                                        return SideTitleWidget(
                                          axisSide: AxisSide.bottom,
                                          angle: math.radians(-90),
                                          space: 11,
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
                                            reservedSize: 25,
                                            getTitlesWidget: (xValue, titleMeta) {
                                              String formattedNumber =
                                                  xValue.toStringAsPrecision(1);
                                              return SideTitleWidget(
                                                axisSide: AxisSide.left,
                                                //child: Text(xValue == xValue.roundToDouble() ? "$xValue" : ''),
                                                child: Text(
                                                  formattedNumber,
                                                  style: const TextStyle(fontSize: 8),
                                                ),
                                              );
                                            })),
                                  ),
                                  //maxY: 10.0,
                                  gridData: FlGridData(show: false),
                                  borderData: FlBorderData(show: false),
                                ),
                                swapAnimationDuration:
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

    //final rawData = await rootBundle.loadString(filepath);
    List<Usage> data = _rawData!;
    DataAggregator dataAggregator = DataAggregator(_duration, _ending, _prices);
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
    } on NotEnoughDataException catch (e) {
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

  DataAggregator(this._duration, this._ending, this._prices);

  aggregateData(List<Usage> data) {
    int numMeters =
        data.map((u) => u.channelIdentifier!).reduce((value, element) => element).length;
    //int numMeters = 3;
    //print('numMeters=$numMeters');

    DateTime latest =
        DateTime.parse(data.last.date!).subtract(_ending).add(const Duration(days: 1));
    DateTime earliest = latest.subtract(_duration);
    //print('latest=$latest earliest=$earliest');

    Map<int, double> stackedValue = {};
    Map<int, List<double>> stackedValues = {};
    Map<int, double> feedInValue = {};

    bool beforeRange = false;
    bool afterRange = false;

    for (int n = 0; n < data.length ~/ numMeters; n++) {
      Usage record = data[n];
      //print("adding record=" + record.startTime!.substring(0, 18) + "0");
      DateTime date = DateTime.parse(record.nemTime!)
          .add(const Duration(hours: 10))
          .subtract(const Duration(minutes: METER_INTERVAL));
      if (date.isBefore(earliest)) {
        continue; // Skip data outside of range
      }
      if (date.isAtSameMomentAs(earliest)) {
        beforeRange = true;
      }
      if (date.isAtSameMomentAs(latest.subtract(const Duration(minutes: 30)))) {
        afterRange = true;
      }
      if (date.isAfter(latest) || date.isAtSameMomentAs(latest)) {
        continue; // Skip data outside of range
      }
      //print('Allowed date=$date');

      int graphPos = date.hour * 2 + date.minute ~/ 30;
      newTitles[graphPos] = newTitles[graphPos] ?? date.toString().substring(11, 16);

      for (int meterNum = 0; meterNum < numMeters; meterNum++) {
        record = data[n + meterNum * data.length ~/ numMeters];
        //print("adding date=$date record=${record.kwh}");
        int channelType = record.channelType == "controlledLoad"
            ? 1
            : record.channelType == "feedIn"
                ? 2
                : 0;
        if (channelType != 2) {
          // Ignore feed in tariff here
          stackedValue[graphPos] =
              (stackedValue[graphPos] ?? 0.0) + (_prices ? record.cost! / 100 : record.kwh!);
          stackedValues[graphPos] = (stackedValues[graphPos] ??
              List<double>.generate(numMeters + (_prices ? 1 : 0), (index) => 0.0));
          stackedValues[graphPos]![channelType] = (stackedValues[graphPos]![channelType]) +
              (_prices ? record.cost! / 100 : record.kwh!);
        } else {
          // Calculate feed in tarrif
          feedInValue[graphPos] =
              (feedInValue[graphPos] ?? 0.0) + (_prices ? record.cost! / 100 : record.kwh!);
        }
      }

      if (_prices) {
        double dailySupplyChargePerInterval = DAILY / 24 / (60 / METER_INTERVAL);
        double dailySupplyChargePer30Mins = DAILY / 24 / 2;
        stackedValue[graphPos] = stackedValue[graphPos]! + dailySupplyChargePerInterval;
        stackedValues[graphPos]![numMeters] = dailySupplyChargePer30Mins * _duration.inDays;
      }
    }

    //print('beforeRange=$beforeRange afterRange=$afterRange');
    if (!beforeRange || !afterRange) {
      // If there wasn't enough data to answer the questions
      throw NotEnoughDataException();
    }

    for (int graphPos in stackedValue.keys) {
      //print("feedInValue=$feedInValue");
      //print("saving graphPos=$graphPos record[1]=${stackedValue[graphPos]}");
      newData[graphPos] = BarChartGroupData(x: graphPos, barRods: [
        makeRodData(graphPos, stackedValue[graphPos]!, stackedValues[graphPos]!.reversed.toList(),
            feedInValue[graphPos] ?? 0.0)
      ]);
    }
  }

  double roundDouble(double value, int places) {
    num mod = pow(10.0, places);
    return ((value * mod).ceilToDouble() / mod);
  }

  BarChartRodData makeRodData(
      int graphPos, double value, List<double> stackedValues, double feedInValue) {
    double rodCumulative = 0.0;
    int i = 0;
    //print("meterNum=$meterNum");
    return BarChartRodData(
      toY: roundDouble(value, _prices ? 2 : 3),
      // colors: [
      //   const Color(0xFFFFAB5E),
      //   const Color(0xFFFFD336),
      // ],
      width: 6, // / _duration.inDays,
      //borderRadius: BorderRadius.circular(2),
      rodStackItems: stackedValues
          .map((e) => BarChartRodStackItem(rodCumulative,
              rodCumulative += roundDouble(e, _prices ? 2 : 3), _getCostColor(i++, graphPos)))
          .toList(),
      backDrawRodData: BackgroundBarChartRodData(
        show: true,
        toY: feedInValue,
        color: colors[6],
      ),
    );
  }

  Color _getCostColor(int meterNum, int graphPos) {
    //print("meterNum=$meterNum graphPos=$graphPos");
    if (!_prices && meterNum == 2 || _prices && meterNum == 3) {
      return colors[1]; // Controlled
    } else if (_prices && meterNum == 0) {
      return colors[0]; // Supply
    } else if (graphPos < 7 * 2) {
      return colors[2]; // Off peak
    } else if (graphPos < 9 * 2) {
      return colors[4]; // Peak
    } else if (graphPos < 17 * 2) {
      return colors[3]; // Shoulder
    } else if (graphPos < 20 * 2) {
      return colors[4]; // Peak
    } else if (graphPos < 22 * 2) {
      return colors[3]; // Shoulder
    } else {
      return colors[2]; // Off peak
    }
  }

  // double _getCost(int meterNum, int weekday, int graphPos, double value) {
  //   if (meterNum == 0) {
  //     return value * CONTROLLED; // Controlled
  //   } else if (weekday == DateTime.saturday || weekday == DateTime.sunday) {
  //     return value * OFFPEAK; // Off peak
  //   } else if (graphPos < 7 * 2) {
  //     return value * OFFPEAK; // Off peak
  //   } else if (graphPos < 17 * 2) {
  //     return value * SHOULDER; // Shoulder
  //   } else if (graphPos < 20 * 2) {
  //     return value * PEAK; // Peak
  //   } else if (graphPos < 22 * 2) {
  //     return value * SHOULDER; // Shoulder
  //   } else {
  //     return value * OFFPEAK; // Off peak
  //   }
  // }
}

class NotEnoughDataException implements Exception {}
