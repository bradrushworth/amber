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
  const BarChartWidget1({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return BarChartState();
  }
}

class BarChartState extends State<BarChartWidget1> {
  late List<List<dynamic>> _csvFileData;
  late MyThemeModel _themeModel;
  List<BarChartGroupData> _barChartData = [];
  List<String> _barChartTitles = [];

  @override
  Widget build(BuildContext context) {
    openFile('assets/Your_Usage_List_202201050902334196.csv');
    return Consumer<MyThemeModel>(
      builder: (context, themeModel, child) {
        _themeModel = themeModel;
        return Column(
          children: [
            const TopSectionWidget(
              title: 'Bar Graph',
              legends: [],
              padding: EdgeInsets.only(left: 8, right: 18, top: 8, bottom: 8),
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
                        reservedSize: 75,
                        showTitles: true,
                        rotateAngle: -90,
                        getTitles: (xValue) {
                          return _barChartTitles[xValue.toInt()];
                        },
                      ),
                      leftTitles: SideTitles(
                        showTitles: true,
                        interval: 20,
                        reservedSize: 32,
                      ),
                    ),
                    //maxY: 140,
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
    DataAggregator dataAggregator = DataAggregator(_themeModel);
    dataAggregator.aggregateData(data);

    setState(() {
      _csvFileData = data;
      _barChartData = dataAggregator.newData;
      _barChartTitles = dataAggregator.newTitles;
      //.map((r) => BarChartGroupData(x: i++, barRods: [makeRodData(r)]))
      //.toList();
    });
  }
}

class DataAggregator {
  final List<BarChartGroupData> newData = [];
  final List<String> newTitles = [];
  late MyThemeModel _themeModel;
  late BarChartGroupData _lastData;
  DateTime? _lastDate;

  DataAggregator(MyThemeModel themeModel) {
    _themeModel = themeModel;
  }

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
    int i = 0;
    double stackedValue = 0;
    List<double> stackedValues = [];
    for (List<dynamic> record in data) {
      DateTime date = DateTime.parse(dateParse(record[0]));
      _lastDate ??= date; // Assign if null
      if (date == _lastDate) {
        stackedValue += record[1];
        stackedValues.add(record[1]);
        continue;
      } else {
        newData.add(BarChartGroupData(
            x: i++, barRods: [makeRodData(stackedValue, stackedValues)]));
        newTitles.add(_lastDate.toString().substring(0, 16));

        _lastDate = date;
        stackedValue = record[1];
        stackedValues = [record[1]];
      }
    }
    //_newData.add(_lastData);
  }

  BarChartRodData makeRodData(double value, List<double> stackedValues) {
    double rodCumulative = 0.0;
    List<Color> colors = [
      const Color(0xFFFF3E8D),
      const Color(0xFF5974FF),
      Colors.blue,
    ];
    int i = 0;
    return BarChartRodData(
      y: value,
      // colors: [
      //   const Color(0xFFFFAB5E),
      //   const Color(0xFFFFD336),
      // ],
      width: 10,
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
      //   y: value,
      // ),
    );
  }
}
