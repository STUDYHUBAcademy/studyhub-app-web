/// How a student is attributed for one specific course/session — resolved by
/// preferring a per-enrollment/per-session override over the student's own
/// stored default, since the same student can come via a marketer for one
/// course and directly for another.
class ResolvedSource {
  const ResolvedSource({
    required this.source,
    this.marketerName,
    this.commissionPct,
    this.commissionAmount,
  });

  final String source; // direct | haraj | marketer
  final String? marketerName;

  /// Fixed 1% commission for 'haraj'. Not used for 'marketer' — see
  /// [commissionAmount].
  final double? commissionPct;

  /// Flat commission owed to the marketer — used instead of [commissionPct]
  /// when [source] is 'marketer'.
  final double? commissionAmount;
}

ResolvedSource resolveAcquisitionSource({
  required String? overrideSource,
  required String? overrideMarketerName,
  required double? overrideCommissionPct,
  double? overrideCommissionAmount,
  required String? studentSource,
  required String? studentMarketerName,
  required double? studentCommissionPct,
  double? studentCommissionAmount,
}) {
  if (overrideSource != null) {
    return ResolvedSource(
      source: overrideSource,
      marketerName: overrideMarketerName,
      commissionPct: overrideCommissionPct,
      commissionAmount: overrideCommissionAmount,
    );
  }
  return ResolvedSource(
    source: studentSource ?? 'direct',
    marketerName: studentMarketerName,
    commissionPct: studentCommissionPct,
    commissionAmount: studentCommissionAmount,
  );
}
