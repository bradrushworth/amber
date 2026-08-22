import '../model/Usage.dart';
import '../utils.dart';

/// Sums `cost` (cents -> dollars) or `kwh` of general+controlledLoad records
/// for the single AEST day ending [ending] days back from the data's last
/// date. Mirrors the day-window arithmetic used by
/// `DataAggregator.aggregateData` in `bar_chart.dart` (latest/earliest, with
/// duration = 1 day).
///
/// Feed-in cost is ADDED for the cost sum (feed-in cost is already negative)
/// and excluded from the kWh sum.
double sumForDay(List<Usage> data, Duration ending, {required bool cost}) {
  if (data.isEmpty) return 0;
  final latest = Utils.toLocal(DateTime.parse('${data.last.date!}T00:00:00+10:00')
      .subtract(ending)
      .add(const Duration(days: 1)));
  final earliest = latest.subtract(const Duration(days: 1));
  double total = 0;
  for (final u in data) {
    final d = Utils.toLocal(
        DateTime.parse(u.nemTime!).subtract(Duration(minutes: u.duration ?? 30)));
    if (d.isBefore(earliest) || !d.isBefore(latest)) continue;
    if (cost) {
      total += u.cost ?? 0;
    } else if (u.channelType != 'feedIn') {
      total += u.kwh ?? 0;
    }
  }
  return cost ? total / 100.0 : total;
}
