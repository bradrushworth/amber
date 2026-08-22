import '../model/Usage.dart';
import '../utils.dart';

/// Sums `cost` (cents -> dollars) or `kwh` of general+controlledLoad records
/// for a window of [duration] ending [ending] back from the data's last
/// date. Mirrors the day-window arithmetic used by
/// `DataAggregator.aggregateData` in `bar_chart.dart` (latest/earliest).
///
/// Feed-in cost is ADDED for the cost sum (feed-in cost is already negative)
/// and excluded from the kWh sum.
double sumForRange(List<Usage> data, Duration duration, Duration ending,
    {required bool cost}) {
  if (data.isEmpty) return 0;
  final latest = Utils.toLocal(DateTime.parse('${data.last.date!}T00:00:00+10:00')
      .subtract(ending)
      .add(const Duration(days: 1)));
  final earliest = latest.subtract(duration);
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

/// Sums `cost`/`kwh` for the single AEST day ending [ending] days back from
/// the data's last date. See [sumForRange] for the underlying window math.
double sumForDay(List<Usage> data, Duration ending, {required bool cost}) =>
    sumForRange(data, const Duration(days: 1), ending, cost: cost);

/// Sums feed-in-channel `cost` (cents -> dollars, typically negative) for a
/// window of [duration] ending [ending] back from the data's last date. Uses
/// the same window math as [sumForRange] but is restricted to feed-in
/// records only, so it can't be expressed via that function's `cost` flag
/// (which sums general+controlledLoad+feedIn cost together).
double sumFeedIn(List<Usage> data, Duration duration, Duration ending) {
  if (data.isEmpty) return 0;
  final latest = Utils.toLocal(DateTime.parse('${data.last.date!}T00:00:00+10:00')
      .subtract(ending)
      .add(const Duration(days: 1)));
  final earliest = latest.subtract(duration);
  double total = 0;
  for (final u in data) {
    if (u.channelType != 'feedIn') continue;
    final d = Utils.toLocal(
        DateTime.parse(u.nemTime!).subtract(Duration(minutes: u.duration ?? 30)));
    if (d.isBefore(earliest) || !d.isBefore(latest)) continue;
    total += u.cost ?? 0;
  }
  return total / 100.0;
}
