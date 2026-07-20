import 'dart:convert';
import 'dart:io';

import 'package:amber/model/Usage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amber/bar_chart.dart';
import 'package:amber/utils.dart';

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
    test('Utils.toLocal pins every timestamp to AEST +10 (DST-blind API)', () {
      final d10 = Utils.toLocal(DateTime.parse('2023-08-12T00:30:00+10:00'));
      expect(d10.hour, 0);
      expect(d10.minute, 30);
      final d11 = Utils.toLocal(DateTime.parse('2023-08-12T01:30:00+11:00'));
      expect(d11.hour, 0);
      expect(d11.minute, 30);
      final dZ = Utils.toLocal(DateTime.parse('2023-08-11T14:30:00Z'));
      expect(dZ.hour, 0);
      expect(dZ.minute, 30);
    });

    test('Aggregation across the DST-start day (first Sun Oct, 23h)', () {
      List<Usage> data = [];
      for (int i = 0; i < 48; i++) {
        final nemTime = DateTime.utc(2023, 9, 30, 14, 0)
            .add(Duration(minutes: (i + 1) * 30))
            .toIso8601String();
        data.add(Usage(
          duration: 30, date: '2023-10-01', nemTime: nemTime,
          kwh: 1.0, channelType: 'general', channelIdentifier: 'E1',
        ));
      }
      final agg =
          DataAggregator(const Duration(days: 1), const Duration(days: 0), false, false, false, 30);
      agg.aggregateData(data);
      expect(agg.newData.length, 48);
      expect(agg.newTitles.length, 48);
      expect(agg.newTitles[0], '00:00');
      expect(agg.newTitles[47], '23:30');
      expect(agg.newData[0]!.barRods.first.toY, closeTo(1.0, 0.001));
      expect(agg.newData[47]!.barRods.first.toY, closeTo(1.0, 0.001));
    });

    test('Aggregation across the DST-end day (first Sun Apr, 25h)', () {
      List<Usage> data = [];
      for (int i = 0; i < 48; i++) {
        final nemTime = DateTime.utc(2023, 4, 1, 14, 0)
            .add(Duration(minutes: (i + 1) * 30))
            .toIso8601String();
        data.add(Usage(
          duration: 30, date: '2023-04-02', nemTime: nemTime,
          kwh: 1.0, channelType: 'general', channelIdentifier: 'E1',
        ));
      }
      final agg =
          DataAggregator(const Duration(days: 1), const Duration(days: 0), false, false, false, 30);
      agg.aggregateData(data);
      expect(agg.newData.length, 48);
      expect(agg.newTitles.length, 48);
      expect(agg.newTitles[0], '00:00');
      expect(agg.newTitles[47], '23:30');
      expect(agg.newData[0]!.barRods.first.toY, closeTo(1.0, 0.001));
      expect(agg.newData[47]!.barRods.first.toY, closeTo(1.0, 0.001));
    });

    test('Feed-in on multi-day tabs: interleaved channels, own day/half-hour', () {
      const double gA = 2.0, fA = 1.0;
      const double gB = 3.0, fB = 1.5;
      List<Usage> data = [];
      void addDay(String date, double g, double f, DateTime base) {
        for (int i = 0; i < 48; i++) {
          final nemTime = base.add(Duration(minutes: (i + 1) * 30)).toIso8601String();
          data.add(Usage(
            duration: 30, date: date, nemTime: nemTime,
            kwh: g, channelType: 'general', channelIdentifier: 'E1',
          ));
          data.add(Usage(
            duration: 30, date: date, nemTime: nemTime,
            kwh: f, channelType: 'feedIn', channelIdentifier: 'E2',
          ));
        }
      }
      addDay('2023-08-12', gA, fA, DateTime.utc(2023, 8, 11, 14, 0));
      addDay('2023-08-13', gB, fB, DateTime.utc(2023, 8, 12, 14, 0));

      final oneDay =
          DataAggregator(const Duration(days: 1), const Duration(days: 0), false, false, false, 30);
      oneDay.aggregateData(data);
      expect(oneDay.newData.length, 48);
      expect(oneDay.newData[0]!.barRods.first.toY, closeTo(gB, 0.001));
      expect(oneDay.newData[0]!.barRods.first.backDrawRodData.toY, closeTo(-fB, 0.001));
      expect(oneDay.newData[0]!.barRods.first.toY, isNot(closeTo(gA, 0.001)));
      expect(oneDay.newData[47]!.barRods.first.toY, closeTo(gB, 0.001));

      final twoDay =
          DataAggregator(const Duration(days: 2), const Duration(days: 0), false, false, false, 30);
      twoDay.aggregateData(data);
      expect(twoDay.newData.length, 48);
      double totalFeedIn = 0.0;
      for (final d in twoDay.newData.values) {
        expect(d.barRods.first.toY, closeTo(gA + gB, 0.001));
        totalFeedIn += d.barRods.first.backDrawRodData.toY;
      }
      expect(totalFeedIn, closeTo(-(48 * (fA + fB)), 0.01));
    });

    test('5-minute sites show canonical half-hour labels (00:00/00:30), not 00:25', () async {
      final List<Map<String, dynamic>> json = [];
      for (int m = 5; m <= 24 * 60; m += 5) {
        final t = DateTime.utc(2023, 8, 12).add(Duration(minutes: m));
        final hh = t.hour.toString().padLeft(2, '0');
        final mm = t.minute.toString().padLeft(2, '0');
        json.add({
          'date': '2023-08-12',
          'nemTime': '2023-08-12T'+hh+':'+mm+':00+10:00',
          'channelType': 'general',
          'kwh': 1.0,
          'perKwh': 100.0,
        });
      }
      final data = json.map((j) => Usage.fromJson(j)).toList();

      final agg = DataAggregator(
          const Duration(days: 1), const Duration(days: 0), true, true, false, 5);
      agg.aggregateData(data);

      expect(agg.newTitles.length, 48);
      expect(agg.newTitles[0], '00:00');
      expect(agg.newTitles[1], '00:30');
      expect(agg.newTitles[47], '23:30');
      expect(agg.newTitles.values.where((t) => t.contains('25')).isEmpty, isTrue);
    });
    test('Forecast Tomorrow tab shows partial data when API returns incomplete future', () {
      // now = 12:00 AEST on 2023-08-12 (a UTC instant that pins to +10).
      final now = DateTime.utc(2023, 8, 12, 2, 0);
      // Tomorrow (2023-08-13) is only partially returned: the first 12
      // half-hours (00:00-06:00), as the Amber API sometimes does.
      List<Usage> data = [];
      for (int i = 0; i < 12; i++) {
        final nemTime = DateTime.utc(2023, 8, 12, 14, 30)
            .add(Duration(minutes: i * 30))
            .toIso8601String();
        data.add(Usage(
          type: 'ForecastInterval', duration: 30, date: '2023-08-13',
          nemTime: nemTime, perKwh: 20.0,
          channelType: 'general', channelIdentifier: 'E1',
        ));
      }
      // Tomorrow tab: duration 1 day, ending -2 days, anchored on now.
      final agg = DataAggregator(const Duration(days: 1), const Duration(days: -2),
          true, true, false, 30, nowOverride: now);
      agg.aggregateData(data);

      expect(agg.newData.length, 48);
      // The 12 received bars show their price (20 c/kWh -> 0.20 dollars).
      expect(agg.newData[0]!.barRods.first.toY, closeTo(0.20, 0.001));
      expect(agg.newData[11]!.barRods.first.toY, closeTo(0.20, 0.001));
      // Bars with no data stay empty (not dropped, no cross-day bleed).
      expect(agg.newData[12]!.barRods.first.toY, closeTo(0.0, 0.001));
      expect(agg.newData[47]!.barRods.first.toY, closeTo(0.0, 0.001));
    });
    // --- Colour / legend fixes ---

    Usage buildRec(DateTime nemTime,
        {double perKwh = 25.0, double cost = 0.25, double kwh = 1.0, String desc = 'veryLow'}) =>
        Usage(
          type: 'ActualInterval',
          duration: 5,
          date: '2023-08-12',
          nemTime: '${nemTime.year}-${nemTime.month.toString().padLeft(2, '0')}-${nemTime.day.toString().padLeft(2, '0')}T${nemTime.hour.toString().padLeft(2, '0')}:${nemTime.minute.toString().padLeft(2, '0')}:00+10:00',
          perKwh: perKwh,
          cost: cost,
          kwh: kwh,
          channelType: 'general',
          channelIdentifier: 'E1',
          descriptor: desc,
        );

    List<Usage> daySpan() => [
          buildRec(DateTime.utc(2023, 8, 12, 0, 5)),
          buildRec(DateTime.utc(2023, 8, 12, 2, 0)),
          buildRec(DateTime.utc(2023, 8, 13, 0, 0)),
        ];

    bool hasSupply(DataAggregator agg) {
      for (final g in agg.newData.values) {
        for (final rod in g.barRods) {
          for (final item in rod.rodStackItems) {
            if (item.color == colors[0] && item.toY > 0.001) return true;
          }
        }
      }
      return false;
    }

    test('solarSponge period uses the distinct sponge colour (not off-peak green)', () {
      final e = CustomRodElement(general)..tariffInformation = 'solarSponge';
      expect(e.getCostColor(), colors[7]);
    });

    test('null tariffInformation falls back to descriptor (veryLow -> green, not orange)', () {
      final e = CustomRodElement(general)
        ..tariffInformation = null
        ..descriptor = 'veryLow';
      // Single-tariff sites return a null period; the bar must render green
      // (off-peak), never the orange "shoulder" a forced null used to map to.
      expect(e.getCostColor(), colors[2]);
      expect(e.getCostColor(), isNot(colors[3]));
    });

    test('peak tariffInformation still maps to the red Peak colour', () {
      final e = CustomRodElement(general)..tariffInformation = 'peak';
      expect(e.getCostColor(), colors[4]);
    });

    test('Supply charge is excluded from price/forecast charts', () {
      final agg = DataAggregator(const Duration(days: 1), const Duration(days: 0), true, true, false, 5);
      agg.aggregateData(daySpan());
      expect(hasSupply(agg), isFalse);
    });

    test('Supply charge is included on cost charts', () {
      final agg = DataAggregator(const Duration(days: 1), const Duration(days: 0), true, false, false, 5);
      agg.aggregateData(daySpan());
      expect(hasSupply(agg), isTrue);
    });
  });
}
