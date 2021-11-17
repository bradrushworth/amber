import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'top_section.dart';

class LineChartWidget2 extends StatelessWidget {
  const LineChartWidget2({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TopSectionWidget(
          title: 'Line Graph',
          legends: [
            Legend(title: 'Omuk', color: const Color(0xFF5974FF)),
            Legend(
              title: 'Tomuk',
              color: const Color(0xFFFF3E8D),
            ),
          ],
          padding: const EdgeInsets.only(left: 8, right: 18, top: 8, bottom: 8),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 18, top: 18, bottom: 18),
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 40),
                      FlSpot(1, 50),
                      FlSpot(2, 60),
                      FlSpot(3, 48),
                      FlSpot(4, 36),
                      FlSpot(5, 58),
                      FlSpot(6, 80),
                      FlSpot(7, 40),
                      FlSpot(8, 31),
                      FlSpot(9, 22),
                      FlSpot(10, 71),
                      FlSpot(11, 120),
                    ],
                    dotData: FlDotData(show: false),
                    colors: const [Color(0xFFFF26B5), Color(0xFFFF5B5B)],
                    isCurved: false,
                    belowBarData: BarAreaData(
                      show: true,
                      colors: const [Color(0x10FF26B5), Color(0x00FF26B5)],
                      gradientFrom: const Offset(0.5, 0),
                      gradientTo: const Offset(0.5, 1),
                    ),
                  ),
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 20),
                      FlSpot(1, 36),
                      FlSpot(2, 60),
                      FlSpot(3, 40),
                      FlSpot(4, 80),
                      FlSpot(5, 90),
                      FlSpot(6, 50),
                      FlSpot(7, 42),
                      FlSpot(8, 64),
                      FlSpot(9, 68),
                      FlSpot(10, 100),
                      FlSpot(11, 95),
                    ],
                    dotData: FlDotData(show: false),
                    colors: const [Color(0xFF905BFF), Color(0xFF268AFF)],
                    isCurved: false,
                    belowBarData: BarAreaData(
                      show: true,
                      colors: const [Color(0x1f268AFF), Color(0x00268AFF)],
                      gradientFrom: const Offset(0.5, 0),
                      gradientTo: const Offset(0.5, 1),
                    ),
                  ),
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
                    showTitles: true,
                    interval: 20,
                    reservedSize: 32,
                  ),
                ),
                maxY: 140,
                minY: 0,
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
