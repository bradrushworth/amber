import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'top_section.dart';
import 'utils.dart';

class LineChartWidget1 extends StatelessWidget {
  const LineChartWidget1({Key? key}) : super(key: key);

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
                      FlSpot(0, 24),
                      FlSpot(1, 24),
                      FlSpot(2, 40),
                      FlSpot(3, 84),
                      FlSpot(4, 100),
                      FlSpot(5, 80),
                      FlSpot(6, 64),
                      FlSpot(7, 86),
                      FlSpot(8, 108),
                      FlSpot(9, 105),
                      FlSpot(10, 105),
                      FlSpot(11, 124),
                    ],
                    dotData: FlDotData(show: false),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF26B5), Color(0xFFFF5B5B)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    isCurved: true,
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: const LinearGradient(
                        colors: [Color(0x10FF26B5), Color(0x00FF26B5)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 40),
                      FlSpot(1, 28),
                      FlSpot(2, 20),
                      FlSpot(3, 18),
                      FlSpot(4, 40),
                      FlSpot(5, 92),
                      FlSpot(6, 88),
                      FlSpot(7, 70),
                      FlSpot(8, 85),
                      FlSpot(9, 102),
                      FlSpot(10, 80),
                      FlSpot(11, 80),
                    ],
                    dotData: FlDotData(show: false),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF268AFF), Color(0xFF905BFF)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    isCurved: true,
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: const LinearGradient(
                        colors: [Color(0x1f268AFF), Color(0x00268AFF)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ],
                titlesData: FlTitlesData(
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                      reservedSize: 6,
                      showTitles: true,
                      getTitlesWidget: (xValue, titleMeta) {
                        return RotatedBox(
                            quarterTurns: 1,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                Utils.monthIntToName(xValue),
                                style: const TextStyle(color: Colors.green),
                                textDirection: TextDirection.rtl,
                                textAlign: TextAlign.center,
                              ),
                            ));
                      },
                    )),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 20,
                        reservedSize: 32,
                      ),
                    )),
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
