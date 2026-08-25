/// A span of time a tutor held a given status, derived from consecutive
/// tutor_status_log rows. [to] is null for the current, ongoing period.
class TutorStatusPeriod {
  const TutorStatusPeriod({required this.status, required this.from, this.to});

  final String status;
  final DateTime from;
  final DateTime? to;

  bool get isOngoing => to == null;

  /// Collapses a chronologically-sorted (oldest first) log into periods.
  static List<TutorStatusPeriod> fromLog(
    List<({String status, DateTime changedAt})> log,
  ) {
    if (log.isEmpty) return [];
    final periods = <TutorStatusPeriod>[];
    for (var i = 0; i < log.length; i++) {
      final entry = log[i];
      final next = i + 1 < log.length ? log[i + 1] : null;
      periods.add(
        TutorStatusPeriod(
          status: entry.status,
          from: entry.changedAt,
          to: next?.changedAt,
        ),
      );
    }
    return periods.reversed.toList();
  }
}
