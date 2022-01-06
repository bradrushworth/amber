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

class BarChartWidget1 extends StatefulWidget {
  late String title;
  late final Duration duration;

  BarChartWidget1(this.title, this.duration, {Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => BarChartState();
}

class BarChartState extends State<BarChartWidget1> {
  late final String _title;
  late final Duration _duration;
  List<BarChartGroupData> _barChartData = [];
  Map<int, String> _barChartTitles = {};

  BarChartState();

  @override
  void initState() {
    _title = widget.title;
    _duration = widget.duration;
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
              legends: [
                Legend(title: 'Regular', color: const Color(0xFF5974FF)),
                Legend(title: 'Controlled', color: const Color(0xFFFF3E8D)),
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
                    //barGroups: ,
                    titlesData: FlTitlesData(
                      rightTitles: SideTitles(showTitles: false),
                      topTitles: SideTitles(showTitles: false),
                      bottomTitles: SideTitles(
                        reservedSize: 40,
                        showTitles: true,
                        interval: 2,
                        rotateAngle: -90,
                        getTitles: (xValue) {
                          //print('xValue=$xValue');
                          if (_barChartTitles.containsKey(xValue.toInt())) {
                            return _barChartTitles[xValue.toInt()]!;
                          }
                          return 'Unknown';
                        },
                      ),
                      leftTitles: SideTitles(
                        showTitles: true,
                        interval: 20,
                        reservedSize: 32,
                      ),
                    ),
                    //maxY: 10.0,
                    gridData: FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                  ),
                  swapAnimationDuration: Duration.zero,
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
    DataAggregator dataAggregator = DataAggregator(_duration);
    dataAggregator.aggregateData(data);

    setState(() {
      //_csvFileData = data;
      _barChartData = dataAggregator.newData.values.toList();
      _barChartTitles = dataAggregator.newTitles;
      //.map((r) => BarChartGroupData(x: i++, barRods: [makeRodData(r)]))
      //.toList();
    });
  }
}

class DataAggregator {
  final SplayTreeMap<int, BarChartGroupData> newData =
      SplayTreeMap<int, BarChartGroupData>();
  final SplayTreeMap<int, String> newTitles = SplayTreeMap<int, String>();
  late Duration _duration;

  //late MyThemeModel _themeModel;
  //late BarChartGroupData _lastData;
  //DateTime? _lastDate;

  DataAggregator(this._duration);

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
      print('numMeters=$numMeters');
    }

    //int i = 0;
    var earlier = DateTime.parse(dateParse(data.last[0]).substring(0, 8))
        .add(const Duration(days: 1))
        .subtract(_duration);
    print('earlier=$earlier');

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
        stackedValue[graphPos] = (stackedValue[graphPos] ?? 0.0) + record[1];
        stackedValues[graphPos] = (stackedValues[graphPos] ??
            List<double>.generate(numMeters, (index) => 0.0));
        stackedValues[graphPos]![meterNum] =
            (stackedValues[graphPos]![meterNum]) + record[1];
      }
    }

    for (int i in stackedValue.keys) {
      //print("saving i=$i record[1]=${stackedValue[i]}");
      newData[i] = BarChartGroupData(x: i, barRods: [
        makeRodData(stackedValue[i]!, stackedValues[i]!.reversed.toList())
      ]);
    }
  }

  BarChartRodData makeRodData(double value, List<double> stackedValues) {
    double rodCumulative = 0.0;
    List<Color> colors = [
      const Color(0xFF5974FF),
      const Color(0xFFFF3E8D),
      Colors.pink,
      Colors.purple,
      Colors.deepOrangeAccent,
      Colors.blueAccent,
    ];
    int i = 0;
    return BarChartRodData(
      y: value,
      // colors: [
      //   const Color(0xFFFFAB5E),
      //   const Color(0xFFFFD336),
      // ],
      width: 10, // / _duration.inDays,
      //borderRadius: BorderRadius.circular(2),
      rodStackItems: stackedValues
          .map((e) => BarChartRodStackItem(
              rodCumulative, rodCumulative += e, colors[i++]))
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
}
