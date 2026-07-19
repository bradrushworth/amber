import 'dart:convert';
import 'dart:io';

import 'package:amber/model/Usage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amber/bar_chart.dart';

void main() {
  group('Bar Chart', () {
    double dailySupplyChargePer30mins = daily / 24 / 2;

    test('1 Day', () async {
      final myData = await File('assets/usage.json').readAsString();
      List<Usage> data = (jsonDecode(myData) as List).map((json) => Usage.fromJson(json)).toList();

      DataAggregator dataAggregator =
          DataAggregator(const Duration(days: 1), const Duration(days: 0), false, false, false, 30);
      dataAggregator.aggregateData(data);

      expect(dataAggregator.newTitles.length, 48);
      expect(dataAggregator.newTitles[0], '00:00');
      expect(dataAggregator.newTitles[1], '00:30');
      expect(dataAggregator.newTitles[46], '23:00');
      expect(dataAggregator.newTitles[47], '23:30');

      expect(dataAggregator.newData.length, 48);
      expect(dataAggregator.newData[0]!.x, 0);
      expect(dataAggregator.newData[1]!.x, 1);
      expect(dataAggregator.newData[46]!.x, 46);
      expect(dataAggregator.newData[47]!.x, 47);

      expect(dataAggregator.newData[0]!.barRods.first.toY, closeTo(0.06, 0.001));
      expect(dataAggregator.newData[47]!.barRods.first.toY, closeTo(0.057, 0.001));

      expect(
          dataAggregator.newData[0]!.barRods.first.rodStackItems.first.fromY, closeTo(0.0, 0.001));
      expect(
          dataAggregator.newData[0]!.barRods.first.rodStackItems.first.toY, closeTo(0.00, 0.001));
      expect(dataAggregator.newData[0]!.barRods.first.rodStackItems.last.fromY,
          closeTo(0.02 + dailySupplyChargePer30mins, 0.01));
      expect(dataAggregator.newData[0]!.barRods.first.rodStackItems.last.toY,
          closeTo(0.02 + dailySupplyChargePer30mins, 0.01));
    });

    test('1 Day Costs', () async {
      final myData = await File('assets/usage.json').readAsString();
      List<Usage> data = (jsonDecode(myData) as List).map((json) => Usage.fromJson(json)).toList();

      DataAggregator dataAggregator =
          DataAggregator(const Duration(days: 1), const Duration(days: 0), true, false, false, 30);
      dataAggregator.aggregateData(data);

      expect(dailySupplyChargePer30mins, closeTo(0.04453541666666667, 0.001));
      expect(dataAggregator.newData[0]!.barRods.first.toY, closeTo(0.05, 0.01));
      expect(dataAggregator.newData[47]!.barRods.first.toY, closeTo(0.05, 0.01));

      expect(
          dataAggregator.newData[0]!.barRods.first.rodStackItems.first.fromY, closeTo(0.0, 0.01));
      expect(dataAggregator.newData[0]!.barRods.first.rodStackItems.first.toY,
          closeTo(0.00 + dailySupplyChargePer30mins, 0.01));
      expect(dataAggregator.newData[0]!.barRods.first.rodStackItems.last.fromY,
          closeTo(0.01 + dailySupplyChargePer30mins, 0.01));
      expect(dataAggregator.newData[0]!.barRods.first.rodStackItems.last.toY,
          closeTo(0.01 + dailySupplyChargePer30mins, 0.01));
    });

    test('2 Days', () async {
      final myData = await File('assets/usage.json').readAsString();
      List<Usage> data = (jsonDecode(myData) as List).map((json) => Usage.fromJson(json)).toList();

      DataAggregator dataAggregator =
          DataAggregator(const Duration(days: 2), const Duration(days: 0), false, false, false, 30);
      dataAggregator.aggregateData(data);

      expect(dataAggregator.newTitles.length, 48);
      expect(dataAggregator.newTitles[0], '00:00');
      expect(dataAggregator.newTitles[1], '00:30');
      expect(dataAggregator.newTitles[46], '23:00');
      expect(dataAggregator.newTitles[47], '23:30');

      expect(dataAggregator.newData.length, 48);
      expect(dataAggregator.newData[0]!.x, 0);
      expect(dataAggregator.newData[47]!.x, 47);

      expect(dataAggregator.newData[0]!.barRods.first.toY, closeTo(0.125, 0.001));
      expect(dataAggregator.newData[47]!.barRods.first.toY, closeTo(0.124, 0.001));

      expect(
          dataAggregator.newData[0]!.barRods.first.rodStackItems.first.fromY, closeTo(0.0, 0.001));
      expect(dataAggregator.newData[0]!.barRods.first.rodStackItems.first.toY, closeTo(0.0, 0.001));
      expect(
          dataAggregator.newData[0]!.barRods.first.rodStackItems.last.fromY, closeTo(0.125, 0.001));
      expect(
          dataAggregator.newData[0]!.barRods.first.rodStackItems.last.toY, closeTo(0.125, 0.001));
    });

    test('1 Day Costs 1 Day Prior', () async {
      final myData = await File('assets/usage.json').readAsString();
      List<Usage> data = (jsonDecode(myData) as List).map((json) => Usage.fromJson(json)).toList();

      DataAggregator dataAggregator =
          DataAggregator(const Duration(days: 1), const Duration(days: 1), true, false, false, 30);
      dataAggregator.aggregateData(data);

      expect(dataAggregator.newTitles.length, 48);
      expect(dataAggregator.newTitles[0], '00:00');
      expect(dataAggregator.newTitles[1], '00:30');
      expect(dataAggregator.newTitles[46], '23:00');
      expect(dataAggregator.newTitles[47], '23:30');

      expect(dataAggregator.newData.length, 48);
      expect(dataAggregator.newData[0]!.x, 0);
      expect(dataAggregator.newData[1]!.x, 1);
      expect(dataAggregator.newData[46]!.x, 46);
      expect(dataAggregator.newData[47]!.x, 47);

      expect(dailySupplyChargePer30mins, closeTo(0.04453541666666667, 0.001));
      expect(dataAggregator.newData[0]!.barRods.first.toY, closeTo(0.05, 0.01));
      expect(dataAggregator.newData[47]!.barRods.first.toY, closeTo(0.05, 0.01));

      expect(
          dataAggregator.newData[0]!.barRods.first.rodStackItems.first.fromY, closeTo(0.00, 0.01));
      expect(dataAggregator.newData[0]!.barRods.first.rodStackItems.first.toY,
          closeTo(0.00 + dailySupplyChargePer30mins, 0.01));
      expect(dataAggregator.newData[0]!.barRods.first.rodStackItems.last.fromY,
          closeTo(0.01 + dailySupplyChargePer30mins, 0.01));
      expect(dataAggregator.newData[0]!.barRods.first.rodStackItems.last.toY,
          closeTo(0.01 + dailySupplyChargePer30mins, 0.01));
    });

    test('1 Day Costs 2 Day Prior', () async {
      final myData = await File('assets/usage.json').readAsString();
      List<Usage> data = (jsonDecode(myData) as List).map((json) => Usage.fromJson(json)).toList();

      DataAggregator dataAggregator =
          DataAggregator(const Duration(days: 1), const Duration(days: 2), true, false, false, 30);
      dataAggregator.aggregateData(data);

      expect(dataAggregator.newTitles.length, 48);
      expect(dataAggregator.newTitles[0], '00:00');
      expect(dataAggregator.newTitles[1], '00:30');
      expect(dataAggregator.newTitles[7], '03:30');
      expect(dataAggregator.newTitles[8], '04:00');
      expect(dataAggregator.newTitles[46], '23:00');
      expect(dataAggregator.newTitles[47], '23:30');

      expect(dataAggregator.newData.length, 48);
      expect(dataAggregator.newData[0]!.x, 0);
      expect(dataAggregator.newData[1]!.x, 1);
      expect(dataAggregator.newData[46]!.x, 46);
      expect(dataAggregator.newData[47]!.x, 47);

      expect(dailySupplyChargePer30mins, closeTo(0.04453541666666667, 0.001));
      expect(dataAggregator.newData[7]!.barRods.first.toY,
          closeTo(1.4835 / 100 + dailySupplyChargePer30mins, 0.01));
      expect(dataAggregator.newData[8]!.barRods.first.toY,
          closeTo(2.8617 / 100 + dailySupplyChargePer30mins, 0.01));

      expect(
          dataAggregator.newData[0]!.barRods.first.rodStackItems.first.fromY, closeTo(0.00, 0.01));
      expect(dataAggregator.newData[0]!.barRods.first.rodStackItems.first.toY, closeTo(0.04, 0.01));
      expect(dataAggregator.newData[0]!.barRods.first.rodStackItems.last.fromY,
          closeTo(0.02 + dailySupplyChargePer30mins, 0.01));
      expect(dataAggregator.newData[0]!.barRods.first.rodStackItems.last.toY,
          closeTo(0.02 + dailySupplyChargePer30mins, 0.01));
    });

    test('1 Day FeedIn', () async {
      final myData = await File('assets/feedin.json').readAsString();
      List<Usage> data = (jsonDecode(myData) as List).map((json) => Usage.fromJson(json)).toList();

      DataAggregator dataAggregator =
          DataAggregator(const Duration(days: 1), const Duration(days: 0), false, false, false, 30);
      dataAggregator.aggregateData(data);

      expect(dataAggregator.newTitles.length, 48);
      expect(dataAggregator.newTitles[0], '00:00');
      expect(dataAggregator.newTitles[1], '00:30');
      expect(dataAggregator.newTitles[46], '23:00');
      expect(dataAggregator.newTitles[47], '23:30');

      expect(dataAggregator.newData.length, 48);
      expect(dataAggregator.newData[0]!.x, 0);
      expect(dataAggregator.newData[1]!.x, 1);
      expect(dataAggregator.newData[46]!.x, 46);
      expect(dataAggregator.newData[47]!.x, 47);

      expect(dataAggregator.newData[0]!.barRods.first.toY, closeTo(0.06, 0.001));
      expect(dataAggregator.newData[47]!.barRods.first.toY, closeTo(0.057, 0.001));

      expect(
          dataAggregator.newData[0]!.barRods.first.rodStackItems.first.fromY, closeTo(0.0, 0.001));
      expect(
          dataAggregator.newData[0]!.barRods.first.rodStackItems.first.toY, closeTo(0.00, 0.001));
      expect(dataAggregator.newData[0]!.barRods.first.rodStackItems.last.fromY,
          closeTo(0.02 + dailySupplyChargePer30mins, 0.01));
      expect(dataAggregator.newData[0]!.barRods.first.rodStackItems.last.toY,
          closeTo(0.02 + dailySupplyChargePer30mins, 0.01));
    });

    test('1 Day FeedIn Costs', () async {
      final myData = await File('assets/feedin.json').readAsString();
      List<Usage> data = (jsonDecode(myData) as List).map((json) => Usage.fromJson(json)).toList();

      DataAggregator dataAggregator =
          DataAggregator(const Duration(days: 1), const Duration(days: 0), true, false, false, 30);
      dataAggregator.aggregateData(data);

      expect(dailySupplyChargePer30mins, closeTo(0.04453541666666667, 0.001));
      expect(dataAggregator.newData[0]!.barRods.first.toY, closeTo(0.05, 0.01));
      expect(dataAggregator.newData[47]!.barRods.first.toY, closeTo(0.05, 0.01));

      expect(
          dataAggregator.newData[0]!.barRods.first.rodStackItems.first.fromY, closeTo(0.0, 0.01));
      expect(dataAggregator.newData[0]!.barRods.first.rodStackItems.first.toY,
          closeTo(0.00 + dailySupplyChargePer30mins, 0.01));
      expect(dataAggregator.newData[0]!.barRods.first.rodStackItems.last.fromY,
          closeTo(0.01 + dailySupplyChargePer30mins, 0.01));
      expect(dataAggregator.newData[0]!.barRods.first.rodStackItems.last.toY,
          closeTo(0.01 + dailySupplyChargePer30mins, 0.01));
    });

    test('1 Day 5-minute intervals', () {
      // Build one full day of 5-minute 'general' usage, each interval = 1.0 kWh.
      // Bars are fixed half-hour buckets, so the 288 five-minute intervals are
      // aggregated into 48 bars (6 intervals summed per half-hour bar).
      List<Usage> data = [];
      for (int i = 0; i < 288; i++) {
        final nemTime = DateTime.utc(2023, 8, 11, 14, 5)
            .add(Duration(minutes: i * 5))
            .toIso8601String();
        data.add(Usage(
          type: 'Usage',
          duration: 5,
          date: '2023-08-12',
          endTime: nemTime,
          quality: 'billable',
          kwh: 1.0,
          nemTime: nemTime,
          perKwh: 0.0,
          channelType: 'general',
          channelIdentifier: 'E1',
          cost: 0.0,
        ));
      }

      final dataAggregator =
          DataAggregator(const Duration(days: 1), const Duration(days: 0), false, false, false, 5);
      dataAggregator.aggregateData(data);

      expect(dataAggregator.newData.length, 48);
      expect(dataAggregator.newTitles.length, 48);
      expect(dataAggregator.newTitles[0], '00:00');
      expect(dataAggregator.newTitles[1], '00:30');
      expect(dataAggregator.newTitles[2], '01:00');
      // Each half-hour bar sums 6 five-minute intervals of 1.0 kWh = 6.0.
      expect(dataAggregator.newData[0]!.barRods.first.toY, closeTo(6.0, 0.001));
      expect(dataAggregator.newData[2]!.barRods.first.toY, closeTo(6.0, 0.001));
    });



    test('Forecast 5-minute prices are averaged not summed', () {
      // Forecast/price charts show the price (perKwh), which is intensive:
      // the 6 five-minute intervals in a half-hour bar must be AVERAGED, not
      // summed (summing made past/current prices ~6x too high).
      List<Usage> data = [];
      for (int i = 0; i < 288; i++) {
        final nemTime = DateTime.utc(2023, 8, 11, 14, 5)
            .add(Duration(minutes: i * 5))
            .toIso8601String();
        data.add(Usage(
          type: 'ForecastInterval',
          duration: 5,
          date: '2023-08-12',
          nemTime: nemTime,
          perKwh: 30.0,
          channelType: 'general',
          channelIdentifier: 'E1',
        ));
      }

      final dataAggregator =
          DataAggregator(const Duration(days: 1), const Duration(days: 0), true, true, false, 5);
      dataAggregator.aggregateData(data);

      expect(dataAggregator.newData.length, 48);
      // 30 c/kWh -> $0.30/kWh, averaged (not 6 x 0.30 = 1.80).
      expect(dataAggregator.newData[0]!.barRods.first.toY, closeTo(0.30, 0.001));
      expect(dataAggregator.newData[2]!.barRods.first.toY, closeTo(0.30, 0.001));
    });

    test('Interleaved multi-channel data buckets by its own timestamp', () {
      // The live Amber API interleaves channels (g, f, g, f, ...) rather than
      // returning them in blocks. Each record must be bucketed on its own
      // nemTime so feed-in values land in the right bar (and none are lost).
      List<Usage> data = [];
      for (int i = 0; i < 48; i++) {
        final nemTime = DateTime.utc(2023, 8, 11, 14, 30)
            .add(Duration(minutes: i * 30))
            .toIso8601String();
        data.add(Usage(
          duration: 30,
          date: '2023-08-12',
          nemTime: nemTime,
          kwh: 2.0,
          channelType: 'general',
          channelIdentifier: 'E1',
        ));
        data.add(Usage(
          duration: 30,
          date: '2023-08-12',
          nemTime: nemTime,
          kwh: 1.0,
          channelType: 'feedIn',
          channelIdentifier: 'E2',
        ));
      }

      final dataAggregator =
          DataAggregator(const Duration(days: 1), const Duration(days: 0), false, false, false, 30);
      dataAggregator.aggregateData(data);

      expect(dataAggregator.newData.length, 48);
      expect(dataAggregator.newData[0]!.barRods.first.toY, closeTo(2.0, 0.001));
      expect(dataAggregator.newData[0]!.barRods.first.backDrawRodData.toY, closeTo(-1.0, 0.001));
      expect(dataAggregator.newData[47]!.barRods.first.toY, closeTo(2.0, 0.001));
      expect(dataAggregator.newData[47]!.barRods.first.backDrawRodData.toY, closeTo(-1.0, 0.001));
    });

    test('Supply charge added once per half-hour bar (30-min and 5-min)', () {
      // The daily supply charge is spread across the 48 half-hour bars. On a
      // 5-minute site the six intervals in a bar must NOT each add supply
      // (that inflated cost bars ~6x on the supply component).
      List<Usage> build(int interval) {
        final perDay = 24 * 60 ~/ interval;
        final data = <Usage>[];
        for (int i = 0; i < perDay; i++) {
          final nemTime = DateTime.utc(2023, 8, 11, 14, 0)
              .add(Duration(minutes: (i + 1) * interval))
              .toIso8601String();
          data.add(Usage(
            duration: interval, date: '2023-08-12', nemTime: nemTime,
            kwh: 1.0, cost: 10.0, perKwh: 20.0,
            channelType: 'general', channelIdentifier: 'E1',
          ));
        }
        return data;
      }

      final supplyPerBar = DataAggregator.roundDouble(daily / 24 / 2, true);

      final agg30 =
          DataAggregator(const Duration(days: 1), const Duration(days: 0), true, false, false, 30);
      agg30.aggregateData(build(30));
      // One 30-min interval cost (0.10) + a single supply charge.
      expect(agg30.newData[0]!.barRods.first.toY, closeTo(0.10 + supplyPerBar, 0.001));

      final agg5 =
          DataAggregator(const Duration(days: 1), const Duration(days: 0), true, false, false, 5);
      agg5.aggregateData(build(5));
      // Six 5-min costs summed (0.60) + exactly ONE supply charge per bar.
      expect(agg5.newData[0]!.barRods.first.toY, closeTo(0.60 + supplyPerBar, 0.001));
    });

    test('Usage aggregates correctly for 15-minute intervals', () {
      // Intervals other than 5/30 that still divide 30 must also bucket right.
      List<Usage> data = [];
      for (int i = 0; i < 96; i++) {
        final nemTime = DateTime.utc(2023, 8, 11, 14, 0)
            .add(Duration(minutes: (i + 1) * 15))
            .toIso8601String();
        data.add(Usage(
          duration: 15, date: '2023-08-12', nemTime: nemTime,
          kwh: 1.0, channelType: 'general', channelIdentifier: 'E1',
        ));
      }
      final agg =
          DataAggregator(const Duration(days: 1), const Duration(days: 0), false, false, false, 15);
      agg.aggregateData(data);
      expect(agg.newData.length, 48);
      // Two 15-min intervals summed per half-hour bar.
      expect(agg.newData[0]!.barRods.first.toY, closeTo(2.0, 0.001));
      expect(agg.newData[47]!.barRods.first.toY, closeTo(2.0, 0.001));
    });

    test('Forecast price ignores the cost field and uses perKwh', () {
      // Past/current price intervals can carry a cost ($ total). The forecast
      // charts must plot the price (perKwh), never cost, or historic/current
      // bars come out several times too high.
      List<Usage> data = [];
      for (int i = 0; i < 48; i++) {
        final nemTime = DateTime.utc(2023, 8, 11, 14, 0)
            .add(Duration(minutes: (i + 1) * 30))
            .toIso8601String();
        data.add(Usage(
          type: 'ActualInterval',
          duration: 30, date: '2023-08-12', nemTime: nemTime,
          perKwh: 25.0, cost: 999.0, // cost is a decoy; must be ignored
          channelType: 'general', channelIdentifier: 'E1',
        ));
      }
      final agg =
          DataAggregator(const Duration(days: 1), const Duration(days: 0), true, true, false, 30);
      agg.aggregateData(data);
      // 25 c/kWh -> $0.25/kWh, not the 999 cost decoy.
      expect(agg.newData[0]!.barRods.first.toY, closeTo(0.25, 0.001));
    });
  });
}
