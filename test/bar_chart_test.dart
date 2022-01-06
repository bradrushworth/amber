import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:momentum_energy/bar_chart1.dart';

void main() {
  group('Bar Chart', () {
    test('1 Day', () async {
      final myData = await File('assets/Your_Usage_List_Sample.csv').readAsString();
      List<List<dynamic>> data =
          const CsvToListConverter().convert(myData, shouldParseNumbers: true);
      List<dynamic> fieldNames = data.removeAt(0);
      expect(fieldNames.length, 3);
      expect(fieldNames[0].trim(), 'Date and Time');
      expect(fieldNames[1].trim(), 'Read Value - kWh (kilowatt hours)');
      expect(fieldNames[2].trim(), 'Reading quality');

      DataAggregator dataAggregator = DataAggregator(const Duration(days: 1), false);
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

      expect(dataAggregator.newData[0]!.barRods.first.y, 0.274);
      expect(dataAggregator.newData[1]!.barRods.first.y, 0.252);
      expect(dataAggregator.newData[11]!.barRods.first.y, 0.734);
      expect(dataAggregator.newData[46]!.barRods.first.y, closeTo(0.116, 0.001));
      expect(dataAggregator.newData[47]!.barRods.first.y, 0.099);

      expect(dataAggregator.newData[11]!.barRods.first.rodStackItems.first.fromY, closeTo(0.0, 0.001));
      expect(dataAggregator.newData[11]!.barRods.first.rodStackItems.first.toY, closeTo(0.276, 0.001));
      expect(dataAggregator.newData[11]!.barRods.first.rodStackItems.last.fromY, closeTo(0.276, 0.001));
      expect(dataAggregator.newData[11]!.barRods.first.rodStackItems.last.toY, closeTo(0.734, 0.001));
    });

    test('1 Day Costs', () async {
      final myData = await File('assets/Your_Usage_List.csv').readAsString();
      List<List<dynamic>> data =
      const CsvToListConverter().convert(myData, shouldParseNumbers: true);
      List<dynamic> fieldNames = data.removeAt(0);
      expect(fieldNames.length, 3);
      expect(fieldNames[0].trim(), 'Date and Time');
      expect(fieldNames[1].trim(), 'Read Value - kWh (kilowatt hours)');
      expect(fieldNames[2].trim(), 'Reading quality');

      DataAggregator dataAggregator = DataAggregator(const Duration(days: 1), true);
      dataAggregator.aggregateData(data);

      double dailySupplyChargePer30mins = 1.27787 / 24 / 2;
      expect(dataAggregator.newData[0]!.barRods.first.y, closeTo(0.043 + dailySupplyChargePer30mins, 0.001));
      expect(dataAggregator.newData[1]!.barRods.first.y, closeTo(0.039 + dailySupplyChargePer30mins, 0.001));
      expect(dataAggregator.newData[11]!.barRods.first.y, closeTo(0.095 + dailySupplyChargePer30mins, 0.001));
      expect(dataAggregator.newData[46]!.barRods.first.y, closeTo(0.017 + dailySupplyChargePer30mins, 0.001));
      expect(dataAggregator.newData[47]!.barRods.first.y, closeTo(0.015 + dailySupplyChargePer30mins, 0.001));

      expect(dataAggregator.newData[11]!.barRods.first.rodStackItems.first.fromY, closeTo(0.0, 0.001));
      expect(dataAggregator.newData[11]!.barRods.first.rodStackItems.first.toY, closeTo(dailySupplyChargePer30mins, 0.001));
      expect(dataAggregator.newData[11]!.barRods.first.rodStackItems.last.fromY, closeTo(0.043 + dailySupplyChargePer30mins, 0.001));
      expect(dataAggregator.newData[11]!.barRods.first.rodStackItems.last.toY, closeTo(0.095 + dailySupplyChargePer30mins, 0.001));
    });

    test('2 Days', () async {
      final myData = await File('assets/Your_Usage_List.csv').readAsString();
      List<List<dynamic>> data =
      const CsvToListConverter().convert(myData, shouldParseNumbers: true);
      List<dynamic> fieldNames = data.removeAt(0);
      expect(fieldNames.length, 3);
      expect(fieldNames[0].trim(), 'Date and Time');
      expect(fieldNames[1].trim(), 'Read Value - kWh (kilowatt hours)');
      expect(fieldNames[2].trim(), 'Reading quality');

      DataAggregator dataAggregator = DataAggregator(const Duration(days: 2), false);
      dataAggregator.aggregateData(data);

      expect(dataAggregator.newTitles.length, 48);
      expect(dataAggregator.newTitles[0], '00:00');
      expect(dataAggregator.newTitles[1], '00:30');
      expect(dataAggregator.newTitles[46], '23:00');
      expect(dataAggregator.newTitles[47], '23:30');

      expect(dataAggregator.newData.length, 48);
      expect(dataAggregator.newData[0]!.x, 0);
      expect(dataAggregator.newData[47]!.x, 47);

      expect(dataAggregator.newData[0]!.barRods.first.y, closeTo(0.431, 0.001));
      expect(dataAggregator.newData[1]!.barRods.first.y, closeTo(0.381, 0.001));
      expect(dataAggregator.newData[11]!.barRods.first.y, closeTo(0.847, 0.001));
      expect(dataAggregator.newData[46]!.barRods.first.y, closeTo(0.408, 0.001));
      expect(dataAggregator.newData[47]!.barRods.first.y, closeTo(0.380, 0.001));

      expect(dataAggregator.newData[11]!.barRods.first.rodStackItems.first.fromY, closeTo(0.0, 0.001));
      expect(dataAggregator.newData[11]!.barRods.first.rodStackItems.first.toY, closeTo(0.389, 0.001));
      expect(dataAggregator.newData[11]!.barRods.first.rodStackItems.last.fromY, closeTo(0.389, 0.001));
      expect(dataAggregator.newData[11]!.barRods.first.rodStackItems.last.toY, closeTo(0.847, 0.001));
    });

  });
}
