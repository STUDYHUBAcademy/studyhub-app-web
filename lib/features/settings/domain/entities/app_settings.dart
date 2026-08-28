class AppSettings {
  const AppSettings({required this.tabbyTamaraFeePct});

  /// Default gateway-fee percentage suggested (still editable) whenever a
  /// payment is made via Tabby/Tamara.
  final double tabbyTamaraFeePct;

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      tabbyTamaraFeePct:
          (json['tabby_tamara_fee_pct'] as num?)?.toDouble() ?? 8,
    );
  }
}
