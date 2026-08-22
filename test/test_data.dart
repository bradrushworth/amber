import 'package:amber/model/Usage.dart';

/// 48 half-hourly 'general' usage records for a single day (2023-08-12),
/// shared by widget tests that need a minimal-but-valid usage dataset.
List<Usage> day() => List.generate(48, (i) => Usage(
    type: 'ActualInterval', duration: 30, date: '2023-08-12',
    nemTime: DateTime.utc(2023, 8, 11, 14, 0)
        .add(Duration(minutes: (i + 1) * 30)).toIso8601String(),
    kwh: 1.0, cost: 10.0, perKwh: 20.0,
    channelType: 'general', channelIdentifier: 'E1'));
