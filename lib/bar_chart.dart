import 'dart:collection';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:amber/my_theme_model.dart';
import 'package:provider/provider.dart';
import 'package:vector_math/vector_math.dart' as math;

import 'model/Usage.dart';
import 'top_section.dart';

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
  bool forecast;

  BarChartWidget1(this.rawData, this.title, this.duration,
      {Key? key, this.ending = const Duration(days: 0), this.prices = false, this.forecast = false})
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
                                    Legend(title: 'Amber', color: colors[0]),
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
                                  //[BarChartGroupData(x: 0, barRods: [makeRodData(80)]),],
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
                                  gridData: const FlGridData(show: false),
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
    DataAggregator dataAggregator = DataAggregator(_duration, _ending, _prices, _forecast);
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
  late final bool _forecast;

  DataAggregator(this._duration, this._ending, this._prices, this._forecast);

  aggregateData(List<Usage> data) {
    //print(data.map((u) => u.channelType!).toSet());
    int numMeters = data.map((u) => u.channelType!).toSet().length;
    //numMeters = 1;
    //print('numMeters=$numMeters');

    //print('data.last.date=${data.last.date}');
    //print('data.first.date=${data.first.date}');
    DateTime latest = DateTime.parse('${data.last.date!}T00:00:00+10:00')
        .subtract(_ending)
        .add(const Duration(days: 1))
        //.add(const Duration(hours: 10))
        .toLocal();
    DateTime earliest = latest.subtract(_duration);
    //print('latest=$latest earliest=$earliest');

    Map<int, double> stackedValue = {};
    Map<int, CustomRodGroup> stackedValues = {};
    Map<int, double> feedInValue = {};

    bool beforeRange = false;
    bool afterRange = false;

    for (int n = 0; n < data.length ~/ numMeters; n++) {
      Usage record = data[n];

      //print("adding record=" + record.nemTime!);
      DateTime date = DateTime.parse(record.nemTime!)
          .subtract(const Duration(minutes: METER_INTERVAL))
          //.add(const Duration(hours: 10))
          .toLocal();

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
        //print("adding date=$date record=${record.channelType}");
        // int channelType = record.channelType == "controlledLoad"
        //     ? 1
        //     : record.channelType == "feedIn"
        //         ? 0
        //         : record.channelType == "general"
        //             ? 2
        //             : throw Exception('Unknown channel type!');
        if (record.channelType == "controlledLoad" && _forecast) {
          // Skip the controlled load when forecasting
          continue;
        } else if (record.channelType != "feedIn") {
          // Ignore feed in tariff here
          stackedValue[graphPos] = (stackedValue[graphPos] ?? 0.0) +
              (_prices
                  ? (record.cost ?? record.perKwh!) / 100
                  : record.kwh ?? record.perKwh! / 100);
          // stackedValues[graphPos] = (stackedValues[graphPos] ??
          //     // Always create 3 for general, controlledLoad and feedIn, or 4 including supply
          //     List<double>.generate(3 + (_prices ? 1 : 0), (index) => 0.0));
          //stackedValues[graphPos]![channelType] =
          stackedValues[graphPos] ??= CustomRodGroup();
          stackedValues[graphPos]!.add(record.channelType!, record.tariffInformation?.period,
              _prices ? (record.cost ?? record.perKwh!) / 100 : record.kwh ?? record.perKwh! / 100);
        } else {
          // Calculate feed in tariff
          feedInValue[graphPos] = (feedInValue[graphPos] ?? 0.0) +
              (_prices
                  ? (record.cost ?? record.perKwh!) / 100
                  : record.kwh ?? record.perKwh! / 100);
        }
      }

      if (_prices) {
        // Add the supply charges as required
        double dailySupplyChargePerInterval = DAILY / 24 / (60 / METER_INTERVAL);
        double dailySupplyChargePer30Mins = DAILY / 24 / 2;
        stackedValue[graphPos] = stackedValue[graphPos]! + dailySupplyChargePerInterval;
        //stackedValues[graphPos]![3] = dailySupplyChargePer30Mins * _duration.inDays;
        stackedValues[graphPos]!.add('supply', null, dailySupplyChargePer30Mins);
      }
    }

    //print('beforeRange=$beforeRange afterRange=$afterRange');
    if (!beforeRange || !afterRange) {
      if (!_forecast) {
        // If there wasn't enough data to answer the questions
        throw NotEnoughDataException();
      }

      // Fill in any missing graph positions with zeros
      for (int graphPos = stackedValue.length;
          graphPos < (24 * (60 / METER_INTERVAL));
          graphPos++) {
        //print('graphPos=$graphPos');
        stackedValue[graphPos] = 0.0;
        // stackedValues[graphPos] =
        //     (stackedValues[graphPos] ?? List<double>.generate(1, (index) => 0.0));
        // stackedValues[graphPos]![0] = 0.0;
        stackedValues[graphPos] ??= CustomRodGroup();
        newTitles[graphPos] = newTitles[graphPos] ?? '';
      }
    }

    for (int graphPos in stackedValue.keys) {
      //print("feedInValue=$feedInValue");
      //print("saving graphPos=$graphPos record[1]=${stackedValue[graphPos]}");
      newData[graphPos] = BarChartGroupData(x: graphPos, barRods: [
        makeRodData(graphPos, stackedValue[graphPos]!, stackedValues[graphPos]!,
            feedInValue[graphPos] ?? 0.0)
      ]);
    }
  }

  static double roundDouble(double value, int places) {
    num mod = pow(10.0, places);
    return ((value * mod).ceilToDouble() / mod);
  }

  BarChartRodData makeRodData(
      int graphPos, double value, CustomRodGroup stackedValues, double feedInValue) {
    double rodCumulative = 0.0;
    int i = 0;
    //print("meterNum=$meterNum");
    return BarChartRodData(
      toY: roundDouble(value, _prices || _forecast ? 2 : 3),
      // colors: [
      //   const Color(0xFFFFAB5E),
      //   const Color(0xFFFFD336),
      // ],
      width: 6, // / _duration.inDays,
      //borderRadius: BorderRadius.circular(2),
      rodStackItems: stackedValues
          .toList()
          .map((e) => BarChartRodStackItem(
              rodCumulative,
              rodCumulative += roundDouble(e.amount, _prices || _forecast ? 2 : 3),
              e.getCostColor()))
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
  String channelType;
  String? tariffInformation;

  CustomRodElement(this.channelType);

  Color getCostColor() {
    if (channelType == 'controlledLoad') {
      return colors[1]; // Controlled
    } else if (channelType == 'feedIn') {
      return colors[6]; // Feed In
    } else if (channelType == 'supply') {
      return colors[0]; // Supply
    } else if (tariffInformation == 'offPeak') {
      return colors[2]; // Off peak
    } else if (tariffInformation == 'peak') {
      return colors[4]; // Peak
    } else if (tariffInformation == 'shoulder') {
      return colors[3]; // Shoulder
    } else {
      return colors[5]; // Unknown
    }
  }

  void setTariffInformation(String? tariffInformation) {
    if (tariffInformation != null) this.tariffInformation = tariffInformation;
  }

  void add(num num) {
    amount += num;
  }
}

class CustomRodGroup {
  CustomRodElement supply = CustomRodElement('supply');
  CustomRodElement controlled = CustomRodElement('controlledLoad');
  CustomRodElement general = CustomRodElement('general');
  CustomRodElement feedIn = CustomRodElement('feedIn');

  CustomRodGroup();

  void add(String channelType, String? tariffInformation, num num) {
    if (channelType == 'controlledLoad') {
      controlled.add(num);
    } else if (channelType == 'feedIn') {
      feedIn.add(num);
    } else if (channelType == 'supply') {
      supply.add(num);
    } else if (channelType == 'general') {
      general.setTariffInformation(tariffInformation);
      general.add(num);
    } else {
      throw Exception('Unknown channel type! {$channelType}');
    }
  }

  List<CustomRodElement> toList() {
    return [supply, general, controlled, feedIn];
  }
}
