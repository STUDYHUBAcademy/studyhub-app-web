class AppSettings {
  const AppSettings({
    required this.tabbyTamaraFeePct,
    this.backupSpreadsheetId,
    this.backupSpreadsheetUrl,
    this.lastBackupAt,
  });

  /// Default gateway-fee percentage suggested (still editable) whenever a
  /// payment is made via Tabby/Tamara.
  final double tabbyTamaraFeePct;

  /// The shared Google Sheet the "نسخ احتياطي الآن" feature writes into —
  /// created on first backup, then reused so every backup lands in the
  /// same place for both owners.
  final String? backupSpreadsheetId;
  final String? backupSpreadsheetUrl;
  final DateTime? lastBackupAt;

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      tabbyTamaraFeePct:
          (json['tabby_tamara_fee_pct'] as num?)?.toDouble() ?? 8,
      backupSpreadsheetId: json['backup_spreadsheet_id'] as String?,
      backupSpreadsheetUrl: json['backup_spreadsheet_url'] as String?,
      lastBackupAt: json['last_backup_at'] == null
          ? null
          : DateTime.parse(json['last_backup_at'] as String).toLocal(),
    );
  }
}
