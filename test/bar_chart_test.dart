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
          DataAggregator(const Duration(days: 1), const Duration(days: 0), false, false, false);
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
          DataAggregator(const Duration(days: 1), const Duration(days: 0), true, false, false);
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
          DataAggregator(const Duration(days: 2), const Duration(days: 0), false, false, false);
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
          DataAggregator(const Duration(days: 1), const Duration(days: 1), true, false, false);
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
          DataAggregator(const Duration(days: 1), const Duration(days: 2), true, false, false);
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
          DataAggregator(const Duration(days: 1), const Duration(days: 0), false, false, false);
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
          DataAggregator(const Duration(days: 1), const Duration(days: 0), true, false, false);
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
  });
}
