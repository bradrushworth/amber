import 'package:amber/periods.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computePeriods', () {
    test('30-minute interval, mid-afternoon, no DST', () {
      final now = DateTime.utc(2023, 8, 12, 4, 0);
      final (back, forward) = computePeriods(now, 30);
      expect(back, 76);
      expect(forward, 68);
      expect(back + forward + 1, 145);
    });

    test('5-minute interval fetches 12 periods/hour', () {
      final now = DateTime.utc(2023, 8, 12, 4, 0);
      final (back, forward) = computePeriods(now, 5);
      expect(back, 456);
      expect(forward, 408);
      expect(back + forward + 1, 865);
    });

    test('DST start (first Sun Oct) shifts window by one period-hour', () {
      final now = DateTime.utc(2023, 10, 1, 4, 0);
      final (back, forward) = computePeriods(now, 30);
      expect(back, 74);
      expect(forward, 70);
      expect(back + forward + 1, 145);
    });

    test('DST end (first Sun Apr) shifts window the other way', () {
      final now = DateTime.utc(2023, 4, 2, 4, 0);
      final (back, forward) = computePeriods(now, 30);
      expect(back, 78);
      expect(forward, 66);
      expect(back + forward + 1, 145);
    });

    test('non-DST day in October/April is not adjusted', () {
      final now = DateTime.utc(2023, 10, 15, 4, 0);
      final (back, forward) = computePeriods(now, 30);
      expect(back, 76);
      expect(forward, 68);
    });
  });

  group('dstAdjustmentHours', () {
    test('first Sunday of October returns +1', () {
      expect(dstAdjustmentHours(DateTime(2023, 10, 1, 14, 0)), 1);
    });
    test('first Sunday of April returns -1', () {
      expect(dstAdjustmentHours(DateTime(2023, 4, 2, 14, 0)), -1);
    });
    test('ordinary day returns 0', () {
      expect(dstAdjustmentHours(DateTime(2023, 8, 12, 14, 0)), 0);
    });
  });

  group('pinToAest', () {
    test('pins a UTC instant to AEST +10 wall clock', () {
      final d = pinToAest(DateTime.parse('2023-08-11T14:30:00Z'));
      expect(d.hour, 0);
      expect(d.minute, 30);
    });
  });
}