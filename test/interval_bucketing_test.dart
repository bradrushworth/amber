import 'package:flutter_test/flutter_test.dart';
import 'package:amber/bar_chart.dart';
import 'package:amber/model/Usage.dart';

/// Regression: a 5-minute site's price records drawn on 30-minute bars.
///
/// Amber's `nemTime` is the END of an interval, so a record's start is
/// `nemTime - itsOwnDuration`. The Now tab requests `resolution=<site
/// interval>` (5 for a 5-minute site) but draws those records on 30-minute
/// bars, and the aggregator used to subtract the CHART's bar width instead:
///
///     nemTime - 30   rather than   nemTime - record.duration
///
/// which pushed five of every six readings into the previous half hour. Real
/// data from 2026-08-25 (site 7001090940): 06:30-07:00 settled at ~22c and
/// 07:00-07:30 at ~32c, but the 06:30 bar rendered ~31c, so the app claimed
/// electricity was expensive during a half hour Amber's own app showed as
/// cheap.
void main() {
  /// Six 5-minute price records covering [startHour]:[startMinute] onwards,
  /// stamped the way Amber stamps them: nemTime = the END of each interval.
  List<Usage> halfHourOfFiveMinutePrices({
    required String date,
    required int hour,
    required int minute,
    required double perKwh,
  }) {
    return List.generate(6, (i) {
      final endMinutes = hour * 60 + minute + (i + 1) * 5;
      final h = (endMinutes ~/ 60).toString().padLeft(2, '0');
      final m = (endMinutes % 60).toString().padLeft(2, '0');
      return Usage(
        type: 'ActualInterval',
        duration: 5,
        perKwh: perKwh,
        channelType: general,
        date: date,
        nemTime: '${date}T$h:$m:00+10:00',
      );
    });
  }

  test('5-minute price records land in the half hour they actually cover', () {
    const date = '2026-08-25';
    final data = <Usage>[
      // Cheap overnight through 07:00...
      ...halfHourOfFiveMinutePrices(
          date: date, hour: 6, minute: 0, perKwh: 22.0),
      ...halfHourOfFiveMinutePrices(
          date: date, hour: 6, minute: 30, perKwh: 22.0),
      // ...then the morning jump.
      ...halfHourOfFiveMinutePrices(
          date: date, hour: 7, minute: 0, perKwh: 32.0),
      ...halfHourOfFiveMinutePrices(
          date: date, hour: 7, minute: 30, perKwh: 32.0),
    ];

    // The Now tab's price charts: 30-minute bars, forecast/price mode.
    // (duration, ending, prices, forecast, feedIn, interval)
    final agg = DataAggregator(
      const Duration(days: 1),
      const Duration(days: 0),
      true,
      true,
      false,
      30,
      allowPartial: true,
    );
    agg.aggregateData(data);

    double barAt(String label) {
      final pos = agg.newTitles.entries
          .firstWhere((e) => e.value == label,
              orElse: () => throw StateError('no bar labelled $label'))
          .key;
      return agg.newData[pos]!.barRods.first.toY;
    }

    // Amber's own app showed 22c at 06:30 and 32c at 07:00 this morning.
    expect(barAt('06:30'), closeTo(0.22, 0.005),
        reason: '06:30 must not borrow the 07:00 half hour\'s prices');
    expect(barAt('07:00'), closeTo(0.32, 0.005));
    expect(barAt('06:00'), closeTo(0.22, 0.005));
  });
}
