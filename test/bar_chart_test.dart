import 'dart:io';

import 'package:csv/csv.dart';
import 'package:csv/csv_settings_autodetection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum_energy/bar_chart.dart';

void main() {
  group('Bar Chart', () {
    double dailySupplyChargePer30mins = 2.1109 / 24 / 2;

    test('1 Day', () async {
      final myData = await File('assets/Your_Usage_List_Sample.csv').readAsString();
      List<List<dynamic>> data = const CsvToListConverter(
              csvSettingsDetector: FirstOccurrenceSettingsDetector(eols: ['\r\n', '\n']))
          .convert(myData, shouldParseNumbers: true);
      List<dynamic> fieldNames = data.removeAt(0);
      expect(fieldNames.length, 3);
      expect(fieldNames[0].trim(), 'Date and Time');
      expect(fieldNames[1].trim(), 'Read Value - kWh (kilowatt hours)');
      expect(fieldNames[2].trim(), 'Reading quality');

      DataAggregator dataAggregator =
          DataAggregator(const Duration(days: 1), const Duration(days: 0), false);
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

      expect(dataAggregator.newData[0]!.barRods.first.toY,
          closeTo(0.018 + 0.015 + 0.016 + 0.016 + 0.018 + 0.019, 0.001));
      expect(dataAggregator.newData[47]!.barRods.first.toY,
          closeTo(0.023 + 0.02 + 0.019 + 0.019 + 0.021 + 0.022, 0.001));

      expect(
          dataAggregator.newData[0]!.barRods.first.rodStackItems.first.fromY, closeTo(0.0, 0.001));
      expect(dataAggregator.newData[0]!.barRods.first.rodStackItems.first.toY,
          closeTo(0.018 + 0.015 + 0.016 + 0.016 + 0.018 + 0.019, 0.001));
      expect(dataAggregator.newData[0]!.barRods.first.rodStackItems.last.fromY,
          closeTo(0.018 + 0.015 + 0.016 + 0.016 + 0.018 + 0.019, 0.001));
      expect(dataAggregator.newData[0]!.barRods.first.rodStackItems.last.toY,
          closeTo(0.018 + 0.015 + 0.016 + 0.016 + 0.018 + 0.019, 0.001));
    });

    test('1 Day Costs', () async {
      final myData = await File('assets/Your_Usage_List_Sample.csv').readAsString();
      List<List<dynamic>> data = const CsvToListConverter(
              csvSettingsDetector: FirstOccurrenceSettingsDetector(eols: ['\r\n', '\n']))
          .convert(myData, shouldParseNumbers: true);
      List<dynamic> fieldNames = data.removeAt(0);
      expect(fieldNames.length, 3);
      expect(fieldNames[0].trim(), 'Date and Time');
      expect(fieldNames[1].trim(), 'Read Value - kWh (kilowatt hours)');
      expect(fieldNames[2].trim(), 'Reading quality');

      DataAggregator dataAggregator =
          DataAggregator(const Duration(days: 1), const Duration(days: 0), true);
      dataAggregator.aggregateData(data);

      expect(dailySupplyChargePer30mins, closeTo(0.0440, 0.001));
      expect(
          dataAggregator.newData[0]!.barRods.first.toY,
          closeTo(
              0.2992 * (0.018 + 0.015 + 0.016 + 0.016 + 0.018 + 0.019) + dailySupplyChargePer30mins,
              0.01));
      expect(
          dataAggregator.newData[47]!.barRods.first.toY,
          closeTo(
              0.2992 * (0.023 + 0.02 + 0.019 + 0.019 + 0.021 + 0.022) + dailySupplyChargePer30mins,
              0.01));

      expect(
          dataAggregator.newData[0]!.barRods.first.rodStackItems.first.fromY, closeTo(0.0, 0.01));
      expect(dataAggregator.newData[0]!.barRods.first.rodStackItems.first.toY, closeTo(0.05, 0.01));
      expect(dataAggregator.newData[0]!.barRods.first.rodStackItems.last.fromY,
          closeTo(0.05 + dailySupplyChargePer30mins, 0.01));
      expect(dataAggregator.newData[0]!.barRods.first.rodStackItems.last.toY,
          closeTo(0.05 + dailySupplyChargePer30mins, 0.01));
    });

    test('2 Days', () async {
      final myData = await File('assets/Your_Usage_List_Sample.csv').readAsString();
      List<List<dynamic>> data = const CsvToListConverter(
              csvSettingsDetector: FirstOccurrenceSettingsDetector(eols: ['\r\n', '\n']))
          .convert(myData, shouldParseNumbers: true);
      List<dynamic> fieldNames = data.removeAt(0);
      expect(fieldNames.length, 3);
      expect(fieldNames[0].trim(), 'Date and Time');
      expect(fieldNames[1].trim(), 'Read Value - kWh (kilowatt hours)');
      expect(fieldNames[2].trim(), 'Reading quality');

      DataAggregator dataAggregator =
          DataAggregator(const Duration(days: 2), const Duration(days: 0), false);
      dataAggregator.aggregateData(data);

      expect(dataAggregator.newTitles.length, 48);
      expect(dataAggregator.newTitles[0], '00:00');
      expect(dataAggregator.newTitles[1], '00:30');
      expect(dataAggregator.newTitles[46], '23:00');
      expect(dataAggregator.newTitles[47], '23:30');

      expect(dataAggregator.newData.length, 48);
      expect(dataAggregator.newData[0]!.x, 0);
      expect(dataAggregator.newData[47]!.x, 47);

      expect(
          dataAggregator.newData[0]!.barRods.first.toY,
          closeTo(
              (0.018 + 0.015 + 0.016 + 0.016 + 0.018 + 0.019) +
                  (0.023 + 0.023 + 0.023 + 0.018 + 0.017 + 0.017) +
                  (0.0 + 0.3 + 0.23 + 0.0 + 0.2 + 0.0) +
                  (0.0),
              0.001));
      expect(
          dataAggregator.newData[47]!.barRods.first.toY,
          closeTo(
              (0.023 + 0.02 + 0.019 + 0.019 + 0.021 + 0.022) +
                  (0.016 + 0.017 + 0.019 + 0.019 + 0.02 + 0.019),
              0.001));

      expect(
          dataAggregator.newData[0]!.barRods.first.rodStackItems.first.fromY, closeTo(0.0, 0.001));
      expect(
          dataAggregator.newData[0]!.barRods.first.rodStackItems.first.toY, closeTo(0.224, 0.001));
      expect(
          dataAggregator.newData[0]!.barRods.first.rodStackItems.last.fromY, closeTo(0.224, 0.001));
      expect(
          dataAggregator.newData[0]!.barRods.first.rodStackItems.last.toY, closeTo(0.9535, 0.001));
    });

    test('1 Day Costs 1 Day Prior', () async {
      final myData = await File('assets/Your_Usage_List_Sample.csv').readAsString();
      List<List<dynamic>> data = const CsvToListConverter(
              csvSettingsDetector: FirstOccurrenceSettingsDetector(eols: ['\r\n', '\n']))
          .convert(myData, shouldParseNumbers: true);
      List<dynamic> fieldNames = data.removeAt(0);
      expect(fieldNames.length, 3);
      expect(fieldNames[0].trim(), 'Date and Time');
      expect(fieldNames[1].trim(), 'Read Value - kWh (kilowatt hours)');
      expect(fieldNames[2].trim(), 'Reading quality');

      DataAggregator dataAggregator =
          DataAggregator(const Duration(days: 1), const Duration(days: 1), true);
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

      expect(dailySupplyChargePer30mins, closeTo(0.0440, 0.001));
      expect(
          dataAggregator.newData[0]!.barRods.first.toY,
          closeTo(
              (0.2992 * (0.023 + 0.023 + 0.023 + 0.018 + 0.017 + 0.017)) +
                  (0.1771 * (0.0 + 0.0 + 0.3 + 0.23 + 0.0 + 0.2)) +
                  dailySupplyChargePer30mins,
              0.01));
      expect(
          dataAggregator.newData[47]!.barRods.first.toY,
          closeTo(
              (0.2992 * (0.016 + 0.017 + 0.019 + 0.019 + 0.02 + 0.019)) +
                  (0.1771 * (0.0 + 0.0 + 0.0 + 0.0 + 0.0 + 0.0)) +
                  dailySupplyChargePer30mins,
              0.01));

      expect(
          dataAggregator.newData[0]!.barRods.first.rodStackItems.first.fromY, closeTo(0.00, 0.01));
      expect(dataAggregator.newData[0]!.barRods.first.rodStackItems.first.toY, closeTo(0.05, 0.01));
      expect(
          dataAggregator.newData[0]!.barRods.first.rodStackItems.last.fromY, closeTo(0.08, 0.01));
      expect(
          dataAggregator.newData[0]!.barRods.first.rodStackItems.last.toY, closeTo(0.2299, 0.01));
    });
  });
}
