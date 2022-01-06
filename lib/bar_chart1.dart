import 'dart:collection';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:momentum_energy/my_theme_model.dart';
import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;

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
  late String title;
  late final Duration duration;
  bool prices;

  BarChartWidget1(this.title, this.duration,
      {Key? key, bool this.prices = false})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => BarChartState();
}

class BarChartState extends State<BarChartWidget1> {
  late final String _title;
  late final Duration _duration;
  late final bool _prices;
  List<BarChartGroupData> _barChartData = [];
  Map<int, String> _barChartTitles = {};

  BarChartState();

  @override
  void initState() {
    _title = widget.title;
    _duration = widget.duration;
    _prices = widget.prices;
    openFile('assets/Your_Usage_List.csv');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MyThemeModel>(
      builder: (context, themeModel, child) {
        return Column(
          children: [
            TopSectionWidget(
              title: _title,
              legends: _prices
                  ? [
                      Legend(title: 'Off Peak', color: colors[2]),
                      Legend(title: 'Shoulder', color: colors[3]),
                      Legend(title: 'Peak', color: colors[4]),
                      Legend(title: 'Controlled', color: colors[1]),
                      Legend(title: 'Supply', color: colors[0]),
                    ]
                  : [
                      Legend(title: 'Off Peak', color: colors[2]),
                      Legend(title: 'Shoulder', color: colors[3]),
                      Legend(title: 'Peak', color: colors[4]),
                      Legend(title: 'Controlled', color: colors[1]),
                    ],
              padding:
                  const EdgeInsets.only(left: 8, right: 18, top: 8, bottom: 8),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 18, top: 18, bottom: 18),
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

  openFile(filepath) async {
    final myData = await rootBundle.loadString(filepath);
    List<List<dynamic>> data =
        const CsvToListConverter().convert(myData, shouldParseNumbers: true);
    List<dynamic> fieldNames = data.removeAt(0);
    DataAggregator dataAggregator = DataAggregator(_duration, _prices);
    dataAggregator.aggregateData(data);

    setState(() {
      _barChartData = dataAggregator.newData.values.toList();
      _barChartTitles = dataAggregator.newTitles;
    });
  }
}

class DataAggregator {
  final SplayTreeMap<int, BarChartGroupData> newData =
      SplayTreeMap<int, BarChartGroupData>();
  final SplayTreeMap<int, String> newTitles = SplayTreeMap<int, String>();

  late final Duration _duration;
  late final bool _prices;

  DataAggregator(this._duration, this._prices);

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

    var earlier = DateTime.parse(dateParse(data.last[0]).substring(0, 8))
        .add(const Duration(days: 1))
        .subtract(_duration);
    //print('earlier=$earlier');

    Map<int, double> stackedValue = {};
    Map<int, List<double>> stackedValues = {};

    for (int n = 0; n < data.length; n += numMeters) {
      List<dynamic> record = data[n];
      //print("adding record[0]=${record[0]}");
      DateTime date = DateTime.parse(dateParse(record[0]));
      if (date.isBefore(earlier)) {
        // Skip data outside of range
        continue;
      }

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
        stackedValue[graphPos] = stackedValue[graphPos]! + dailySupplyChargePer30mins;
        stackedValues[graphPos]![numMeters] = dailySupplyChargePer30mins * _duration.inDays;
      }
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
