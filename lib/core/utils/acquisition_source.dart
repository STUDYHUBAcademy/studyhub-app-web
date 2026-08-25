/// How a student is attributed for one specific course/session — resolved by
/// preferring a per-enrollment/per-session override over the student's own
/// stored default, since the same student can come via a marketer for one
/// course and directly for another.
class ResolvedSource {
  const ResolvedSource({
    required this.source,
    this.marketerName,
    this.commissionPct,
  });

  final String source; // direct | haraj | marketer
  final String? marketerName;
  final double? commissionPct;
}

ResolvedSource resolveAcquisitionSource({
  required String? overrideSource,
  required String? overrideMarketerName,
  required double? overrideCommissionPct,
  required String? studentSource,
  required String? studentMarketerName,
  required double? studentCommissionPct,
}) {
  if (overrideSource != null) {
    return ResolvedSource(
      source: overrideSource,
      marketerName: overrideMarketerName,
      commissionPct: overrideCommissionPct,
    );
  }
  return ResolvedSource(
    source: studentSource ?? 'direct',
    marketerName: studentMarketerName,
    commissionPct: studentCommissionPct,
  );
}
