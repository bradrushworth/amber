import 'dart:convert';
import 'dart:io';

import 'package:amber/model/Usage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amber/bar_chart.dart';

void main() {
  group('Bar Chart', () {
    double dailySupplyChargePer30mins = DAILY / 24 / 2;

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
      // With the (buggy) 30-minute-only position formula, distinct 5-minute
      // intervals collide into the same bar, corrupting both the time-range
      // labels and the aggregated values. The fix gives each interval its own
      // position: 24 * 60 / 5 = 288 bars.
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

      expect(dataAggregator.newData.length, 288);
      expect(dataAggregator.newTitles.length, 288);
      expect(dataAggregator.newTitles[0], '00:00');
      expect(dataAggregator.newTitles[2], '00:10');
      expect(dataAggregator.newData[0]!.barRods.first.toY, closeTo(1.0, 0.001));
      // Position 2 must represent only the 00:10 interval, NOT 00:10 + 01:00 etc.
      expect(dataAggregator.newData[2]!.barRods.first.toY, closeTo(1.0, 0.001));
    });


  });
}
