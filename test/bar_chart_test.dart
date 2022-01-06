import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:momentum_energy/bar_chart1.dart';

void main() {
  group('Bar Chart', () {
    test('1 Day', () async {
      final myData = await File('assets/Your_Usage_List.csv').readAsString();
      List<List<dynamic>> data =
          const CsvToListConverter().convert(myData, shouldParseNumbers: true);
      List<dynamic> fieldNames = data.removeAt(0);
      expect(fieldNames.length, 3);
      expect(fieldNames[0].trim(), 'Date and Time');
      expect(fieldNames[1].trim(), 'Read Value - kWh (kilowatt hours)');
      expect(fieldNames[2].trim(), 'Reading quality');

      DataAggregator dataAggregator = DataAggregator(const Duration(days: 1));
      dataAggregator.aggregateData(data);

      expect(dataAggregator.newTitles.length, 47);
      expect(dataAggregator.newTitles[0], '00:00');
      expect(dataAggregator.newTitles[1], '00:30');
      expect(dataAggregator.newTitles[46], '23:00');
      expect(dataAggregator.newTitles[47], null);

      expect(dataAggregator.newData.length, 47);
      expect(dataAggregator.newData[0]!.x, 0);
      expect(dataAggregator.newData[46]!.x, 46);

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

      DataAggregator dataAggregator = DataAggregator(const Duration(days: 2));
      dataAggregator.aggregateData(data);

      expect(dataAggregator.newTitles.length, 48);
      expect(dataAggregator.newTitles[0], '00:00');
      expect(dataAggregator.newTitles[1], '00:30');
      expect(dataAggregator.newTitles[46], '23:00');
      expect(dataAggregator.newTitles[47], '23:30');

      expect(dataAggregator.newData.length, 48);
      expect(dataAggregator.newData[0]!.x, 0);
      expect(dataAggregator.newData[47]!.x, 47);

    });

  });
}
