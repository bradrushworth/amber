import 'dart:collection';
import 'dart:js';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:momentum_energy/my_theme_model.dart';
import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv_settings_autodetection.dart';

import 'top_section.dart';

final List<Color> colors = [
  const Color(0xFF5974FF),
  const Color(0xFFFF3E8D),
  Colors.lightGreen,
  Colors.orange,
  Colors.red,
  Colors.blueAccent,
];

class BarChartWidget1 extends StatefulWidget {
  late String rawData;
  late String title;
  late final Duration duration;
  late final Duration ending;
  bool prices;

  BarChartWidget1(this.rawData, this.title, this.duration,
      {Key? key, this.ending = const Duration(days: 0), this.prices = false})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => BarChartState();

  void refresh(String rawData) {
    print('refresh()');
    //setState(() {
    this.rawData = rawData;
    //});
  }
}

class BarChartState extends State<BarChartWidget1> {
  late String _rawData;
  late final String _title;
  late final Duration _duration;
  late final Duration _ending;
  late final bool _prices;
  late DateTime _dateLastUpdated;
  List<BarChartGroupData> _barChartData = [];
  Map<int, String> _barChartTitles = {};
  bool _loading = true;
  bool _notEnoughData = false;

  @override
  initState() {
    super.initState();
    _rawData = widget.rawData;
    _title = widget.title;
    _duration = widget.duration;
    _ending = widget.ending;
    _prices = widget.prices;
    _dateLastUpdated = DateTime.now();
    parseFile();
  }

  @override
  void didUpdateWidget(BarChartWidget1 oldWidget) {
    super.didUpdateWidget(oldWidget);
    //parseFile();
    print('didUpdateWidget _notEnoughData=$_notEnoughData _title=$_title');
  }

  void refresh() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    _rawData = widget.rawData;
    return Consumer<MyThemeModel>(
      builder: (context, themeModel, child) {
        return Column(
          children: _loading
              ? [
                  const Spacer(),
                  Text(
                    'Data is loading:\n$_title',
                    textAlign: TextAlign.center,
                  ),
                  const Spacer()
                ]
              : _notEnoughData
                  ? [
                      const Spacer(),
                      Text(
                        'Not enough data in file for:\n$_title',
                        textAlign: TextAlign.center,
                      ),
                      const Spacer()
                    ]
                  : [
                      TopSectionWidget(
                        title: _title,
                        legends: _prices
                            ? [
                                Legend(title: 'OP', color: colors[2]),
                                Legend(title: 'S', color: colors[3]),
                                Legend(title: 'P', color: colors[4]),
                                Legend(title: 'C', color: colors[1]),
                                Legend(title: 'Supply', color: colors[0]),
                              ]
                            : [
                                Legend(title: 'Off Peak', color: colors[2]),
                                Legend(title: 'Shoulder', color: colors[3]),
                                Legend(title: 'Peak', color: colors[4]),
                                Legend(title: 'Control', color: colors[1]),
                              ],
                        padding: const EdgeInsets.only(
                            left: 8, right: 18, top: 8, bottom: 8),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(
                              right: 18, top: 18, bottom: 18),
                          child: BarChart(
                            BarChartData(
                              barGroups: _barChartData,
                              //[BarChartGroupData(x: 0, barRods: [makeRodData(80)]),],
                              titlesData: FlTitlesData(
                                rightTitles: SideTitles(showTitles: false),
                                topTitles: SideTitles(showTitles: false),
                                bottomTitles: SideTitles(
                                  reservedSize: 40,
                                  showTitles: true,
                                  interval: 2,
                                  rotateAngle: -90,
                                  getTitles: (xValue) {
                                    return _barChartTitles[xValue.toInt()]!;
                                  },
                                ),
                                leftTitles: SideTitles(
                                  showTitles: true,
                                  interval: 1,
                                  //reservedSize: 32,
                                ),
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

  void parseFile() async {
    if (_rawData.isEmpty) {
      setState(() {
        _barChartData = [];
        _barChartTitles = {};
        _loading = false;
        _notEnoughData = true;
      });
      return;
    }
    if (_rawData == 'Loading') {
      setState(() {
        _barChartData = [];
        _barChartTitles = {};
        _loading = true;
        _notEnoughData = false;
      });
      return;
    }

    //final rawData = await rootBundle.loadString(filepath);
    List<List<dynamic>> data = const CsvToListConverter(
            csvSettingsDetector:
                FirstOccurrenceSettingsDetector(eols: ['\r\n', '\n']))
        .convert(_rawData, shouldParseNumbers: true);
    if (data.isEmpty) {
      print('Data was empty!');
      setState(() {
        _barChartData = [];
        _barChartTitles = {};
        _loading = false;
        _notEnoughData = true;
      });
      return;
    }
    print('Updating data!');
    List<dynamic> fieldNames = data.removeAt(0);
    if (data.isEmpty) {
      print('Data only had field names!');
      setState(() {
        _barChartData = [];
        _barChartTitles = {};
        _loading = false;
        _notEnoughData = true;
      });
      return;
    }
    DataAggregator dataAggregator = DataAggregator(_duration, _ending, _prices);
    try {
      dataAggregator.aggregateData(data);

      setState(() {
        _barChartData = dataAggregator.newData.values.toList();
        _barChartTitles = dataAggregator.newTitles;
        _loading = false;
        _notEnoughData = false;
      });
      setState(() {
        _dateLastUpdated = DateTime.now();
      });
      print('Data updated successfully!');
    } on NotEnoughDataException catch (e) {
      print('NotEnoughDataException!');

      setState(() {
        _barChartData = [];
        _barChartTitles = {};
        _loading = false;
        _notEnoughData = true;
      });
    }
  }
}

class DataAggregator {
  final SplayTreeMap<int, BarChartGroupData> newData =
      SplayTreeMap<int, BarChartGroupData>();
  final SplayTreeMap<int, String> newTitles = SplayTreeMap<int, String>();

  late final Duration _duration, _ending;
  late final bool _prices;

  DataAggregator(this._duration, this._ending, this._prices);

  String dateParse(String input) {
    // e.g. 13/12/21 02:30
    return '20' +
        input.substring(6, 8) +
        input.substring(3, 5) +
        input.substring(0, 2) +
        'T' +
        input.substring(9, 11) +
        ':' +
        input.substring(12, 14) +
        ':00';
  }

  aggregateData(List<List<dynamic>> data) {
    int numMeters = 0;
    {
      String date, previousDate = '';
      for (List record in data) {
        date = record[0];
        numMeters++;
        if (date == previousDate) {
          break;
        }
        previousDate = date;
      }
      //print('numMeters=$numMeters');
    }

    DateTime latest = DateTime.parse(dateParse(data.last[0]).substring(0, 8))
        .subtract(_ending)
        .add(const Duration(days: 1));
    DateTime earliest = latest.subtract(_duration);
    //print('latest=$latest earliest=$earliest');

    Map<int, double> stackedValue = {};
    Map<int, List<double>> stackedValues = {};

    bool beforeRange = false;
    bool afterRange = false;

    for (int n = 0; n < data.length; n += numMeters) {
      List<dynamic> record = data[n];
      //print("adding record[0]=${record[0]}");
      DateTime date = DateTime.parse(dateParse(record[0]));
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
      newTitles[graphPos] = date.toString().substring(11, 16);

      for (int meterNum = 0; meterNum < numMeters; meterNum++) {
        record = data[n + meterNum];
        //print("adding date=$date record[1]=${record[1]}");
        stackedValue[graphPos] = (stackedValue[graphPos] ?? 0.0) +
            (_prices
                ? _getCost(meterNum, date.weekday, graphPos, 0.0 + record[1])
                : record[1]);
        stackedValues[graphPos] = (stackedValues[graphPos] ??
            List<double>.generate(
                numMeters + (_prices ? 1 : 0), (index) => 0.0));
        stackedValues[graphPos]![meterNum] =
            (stackedValues[graphPos]![meterNum]) +
                (_prices
                    ? _getCost(
                        meterNum, date.weekday, graphPos, 0.0 + record[1])
                    : record[1]);
      }

      if (_prices) {
        double dailySupplyChargePer30mins = 1.27787 / 24 / 2;
        stackedValue[graphPos] =
            stackedValue[graphPos]! + dailySupplyChargePer30mins;
        stackedValues[graphPos]![numMeters] =
            dailySupplyChargePer30mins * _duration.inDays;
      }
    }

    //print('beforeRange=$beforeRange afterRange=$afterRange');
    if (!beforeRange || !afterRange) {
      // If there wasn't enough data to answer the questions
      throw NotEnoughDataException();
    }

    for (int graphPos in stackedValue.keys) {
      //print("saving graphPos=$graphPos record[1]=${stackedValue[graphPos]}");
      newData[graphPos] = BarChartGroupData(x: graphPos, barRods: [
        makeRodData(graphPos, stackedValue[graphPos]!,
            stackedValues[graphPos]!.reversed.toList())
      ]);
    }
  }

  BarChartRodData makeRodData(
      int graphPos, double value, List<double> stackedValues) {
    double rodCumulative = 0.0;
    int i = 0;
    //print("meterNum=$meterNum");
    return BarChartRodData(
      y: value,
      // colors: [
      //   const Color(0xFFFFAB5E),
      //   const Color(0xFFFFD336),
      // ],
      width: 7, // / _duration.inDays,
      //borderRadius: BorderRadius.circular(2),
      rodStackItems: stackedValues
          .map((e) => BarChartRodStackItem(rodCumulative, rodCumulative += e,
              true || _prices ? _getCostColor(i++, graphPos) : colors[i++]))
          .toList(),
      // backDrawRodData: BackgroundBarChartRodData(
      //   show: true,
      //   colors: [
      //     _themeModel.isDark()
      //         ? const Color(0xFF1D1D2B)
      //         : const Color(0xFFFCFCFC)
      //   ],
      //   y: value * 1.2, // Dark background bar
      // ),
    );
  }

  Color _getCostColor(int meterNum, int graphPos) {
    //print("meterNum=$meterNum graphPos=$graphPos");
    if (!_prices && meterNum == 1 || _prices && meterNum == 2) {
      return colors[1]; // Controlled
    } else if (_prices && meterNum == 0) {
      return colors[0]; // Supply
    } else if (graphPos < 7 * 2) {
      return colors[2]; // Off peak
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

  double _getCost(int meterNum, int weekday, int graphPos, double value) {
    if (meterNum == 0) {
      return value * 0.11352; // Controlled
    } else if (weekday == DateTime.saturday || weekday == DateTime.sunday) {
      return value * 0.15697; // Off peak
    } else if (graphPos < 7 * 2) {
      return value * 0.15697; // Off peak
    } else if (graphPos < 17 * 2) {
      return value * 0.27709; // Shoulder
    } else if (graphPos < 20 * 2) {
      return value * 0.32131; // Peak
    } else if (graphPos < 22 * 2) {
      return value * 0.27709; // Shoulder
    } else {
      return value * 0.15697; // Off peak
    }
  }
}

class NotEnoughDataException implements Exception {}
