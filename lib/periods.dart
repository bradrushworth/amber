/// Pure period-math helpers for the Amber price/forecast fetch.
///
/// The Amber API reports NSW timestamps in AEST (+10) and is DST-blind, so all
/// window math is performed in AEST. These helpers depend only on `dart:core`
/// and are unit-tested in `test/periods_test.dart`.

/// Pin a timestamp to AEST (+10). Mirrors [Utils.pinToAest] without pulling in
/// Flutter so the period math stays pure and testable.
library periods;

DateTime pinToAest(DateTime dateTime) =>
    dateTime.toUtc().add(const Duration(hours: 10));

/// DST adjustment in hours for an AEST day:
///  * first Sunday of October -> +1 (clocks spring forward, a 23h local day)
///  * first Sunday of April   -> -1 (clocks fall back, a 25h local day)
///  * otherwise               ->  0
///
/// Computed from the AEST calendar so it does not depend on the device
/// timezone or the machine being on DST.
int dstAdjustmentHours(DateTime aestNow) {
  final d = DateTime(aestNow.year, aestNow.month, aestNow.day);
  if (d.month == 10 && d.day <= 7 && d.weekday == DateTime.sunday) {
    return 1;
  }
  if (d.month == 4 && d.day <= 7 && d.weekday == DateTime.sunday) {
    return -1;
  }
  return 0;
}

/// Compute the `(numPeriodsBack, numPeriodsForward)` counts for the Amber
/// `prices/current` API, centred on [now].
///
/// Behaviour preserved from the old inline math in `_getForecast`:
///  * `periodsPerHour = 60 ~/ intervalLength` (5-minute sites fetch 12
///    periods/hour, 30-minute sites fetch 2).
///  * The fetched window is two days of periods (48 bars/day) with [now] in
///    the middle.
///  * On a NSW DST transition day the window is shifted by one hour of periods
///    so the short/long local day is still fully covered.
(int, int) computePeriods(DateTime now, int intervalLength) {
  final periodsPerHour = 60 ~/ intervalLength;
  final periodsPerDay = 24 * periodsPerHour;
  final aest = pinToAest(now);
  final elapsedToday =
      periodsPerHour * aest.hour + aest.minute ~/ intervalLength;
  int numPeriodsBack = periodsPerDay + elapsedToday;
  int numPeriodsForward = 2 * periodsPerDay - elapsedToday;
  final adjustment = dstAdjustmentHours(aest) * periodsPerHour;
  numPeriodsBack -= adjustment;
  numPeriodsForward += adjustment;
  return (numPeriodsBack, numPeriodsForward);
}