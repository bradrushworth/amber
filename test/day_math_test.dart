import 'package:flutter_test/flutter_test.dart';
import 'package:amber/state/day_math.dart';
import 'package:amber/model/Usage.dart';

void main() {
  final data = <Usage>[
    Usage(duration: 30, date: '2023-08-12',
        nemTime: '2023-08-12T10:30:00+10:00', kwh: 2.0, cost: 100.0,
        channelType: 'general', channelIdentifier: 'E1'),
    Usage(duration: 30, date: '2023-08-12',
        nemTime: '2023-08-12T10:30:00+10:00', kwh: 1.0, cost: -40.0,
        channelType: 'feedIn', channelIdentifier: 'B1'),
  ];
  test('cost sums general plus negative feed-in, in dollars', () {
    expect(sumForDay(data, const Duration(days: 0), cost: true), closeTo(0.60, 0.001));
  });
  test('kwh sums consumption only', () {
    expect(sumForDay(data, const Duration(days: 0), cost: false), closeTo(2.0, 0.001));
  });
}
