/// Revenue/payout/profit totals for one tutor, kept per-currency rather than
/// converted (no live FX rates wired in yet) — courses in SAR and private
/// sessions in EGP are shown as separate lines rather than guessed together.
class TutorFinanceSummary {
  const TutorFinanceSummary({
    required this.revenueByCurrency,
    required this.paidByCurrency,
    this.paidSarEquivalent = 0,
  });

  final Map<String, double> revenueByCurrency;
  final Map<String, double> paidByCurrency;

  /// Sum of everything paid to the tutor, converted to SAR — actual SAR
  /// payouts plus the manually-recorded SAR equivalent of any non-SAR
  /// (usually EGP) payouts. Lets us net it against SAR revenue for one
  /// trustworthy bottom-line figure instead of misleading per-currency rows.
  final double paidSarEquivalent;

  static const empty = TutorFinanceSummary(
    revenueByCurrency: {},
    paidByCurrency: {},
  );

  bool get isEmpty => revenueByCurrency.isEmpty && paidByCurrency.isEmpty;

  Map<String, double> get profitByCurrency {
    final currencies = {...revenueByCurrency.keys, ...paidByCurrency.keys};
    return {
      for (final c in currencies)
        c: (revenueByCurrency[c] ?? 0) - (paidByCurrency[c] ?? 0),
    };
  }

  double get revenueSar => revenueByCurrency['SAR'] ?? 0;

  double get netProfitSar => revenueSar - paidSarEquivalent;
}
