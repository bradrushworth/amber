import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'my_theme_model.dart';
import 'top_section.dart';

class BarChartWidget2 extends StatelessWidget {
  const BarChartWidget2({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<MyThemeModel>(builder: (context, themeModel, child) {
      BarChartRodData makeRodData(double y) {
        return BarChartRodData(
          y: y,
          colors: [
            const Color(0xFF1726AB),
            const Color(0xFF364AFF),
          ],
          width: 3,
          borderRadius: BorderRadius.circular(2),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            colors: [
              themeModel.isDark()
                  ? const Color(0xFF1D1D2B)
                  : const Color(0xFFFCFCFC)
            ],
            y: 140,
          ),
        );
      }

      return Column(
        children: [
          const TopSectionWidget(
            title: 'Line Graph',
            legends: [],
            padding: EdgeInsets.only(left: 8, right: 18, top: 8, bottom: 8),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 18, top: 18, bottom: 18),
              child: BarChart(
                BarChartData(
                  barGroups: [
                    BarChartGroupData(x: 0, barRods: [makeRodData(20)]),
                    BarChartGroupData(x: 1, barRods: [makeRodData(40)]),
                    BarChartGroupData(x: 2, barRods: [makeRodData(30)]),
                    BarChartGroupData(x: 3, barRods: [makeRodData(60)]),
                    BarChartGroupData(x: 4, barRods: [makeRodData(75)]),
                    BarChartGroupData(x: 5, barRods: [makeRodData(35)]),
                    BarChartGroupData(x: 6, barRods: [makeRodData(42)]),
                    BarChartGroupData(x: 7, barRods: [makeRodData(33)]),
                    BarChartGroupData(x: 8, barRods: [makeRodData(60)]),
                    BarChartGroupData(x: 9, barRods: [makeRodData(90)]),
                    BarChartGroupData(x: 10, barRods: [makeRodData(86)]),
                    BarChartGroupData(x: 11, barRods: [makeRodData(120)]),
                  ],
                  titlesData: FlTitlesData(
                      rightTitles: SideTitles(showTitles: false),
                      topTitles: SideTitles(showTitles: false),
                      bottomTitles: SideTitles(
                        reservedSize: 6,
                        showTitles: true,
                        getTitles: (xValue) {
                          switch (xValue.toInt()) {
                            case 0:
                              return 'Jan';
                            case 1:
                              return 'Feb';
                            case 2:
                              return 'Mar';
                            case 3:
                              return 'Apr';
                            case 4:
                              return 'May';
                            case 5:
                              return 'Jun';
                            case 6:
                              return 'Jul';
                            case 7:
                              return 'Aug';
                            case 8:
                              return 'Sep';
                            case 9:
                              return 'Oct';
                            case 10:
                              return 'Nov';
                            case 11:
                              return 'Dec';
                            default:
                              throw StateError('Not supported');
                          }
                        },
                      ),
                      leftTitles: SideTitles(
                          showTitles: true, interval: 20, reservedSize: 32)),
                  maxY: 140,
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                ),
                swapAnimationDuration: Duration.zero,
              ),
            ),
          ),
        ],
      );
    });
  }
}
