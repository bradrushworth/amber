import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class LineChartWidget1 extends StatelessWidget {
  const LineChartWidget1({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
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
        colors: const [Color(0xFFFF26B5), Color(0xFFFF5B5B)],
        isCurved: true,
        belowBarData: BarAreaData(
          show: true,
          colors: const [Color(0x10FF26B5), Color(0x00FF26B5)],
          gradientFrom: const Offset(0.5, 0),
          gradientTo: const Offset(0.5, 1),
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
        colors: const [Color(0xFF268AFF), Color(0xFF905BFF)],
        isCurved: true,
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
    );
  }
}
