import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';

import '../core/network/supabase_client.dart';
import '../core/services/google_sheets_backup_service.dart';

/// Every table whose loss would actually hurt — matches what the owner
/// asked to protect against another accidental TRUNCATE. Deliberately
/// leaves out chat/activity-log/profile data: low value, high volume,
/// not what anyone would ask to recover.
const backupTables = <String>[
  'universities',
  'terms',
  'tutor_applications',
  'tutors',
  'tutor_status_log',
  'courses',
  'course_demos',
  'course_terms',
  'marketers',
  'students',
  'enrollments',
  'enrollment_payments',
  'private_sessions',
  'tutor_ledger',
  'academy_expenses',
  'owner_withdrawals',
  'transactions',
  'tasks',
];

class TableBackupResult {
  const TableBackupResult({
    required this.table,
    required this.rowCount,
    this.error,
  });

  final String table;
  final int rowCount;
  final Object? error;

  bool get ok => error == null;
}

class FullBackupResult {
  const FullBackupResult({
    required this.spreadsheetId,
    required this.spreadsheetUrl,
    required this.tableResults,
  });

  final String spreadsheetId;
  final String spreadsheetUrl;
  final List<TableBackupResult> tableResults;

  int get totalRows =>
      tableResults.fold(0, (sum, t) => sum + (t.ok ? t.rowCount : 0));
  List<TableBackupResult> get failures =>
      tableResults.where((t) => !t.ok).toList();
}

class FullBackupService {
  FullBackupService(this._sheets);

  final GoogleSheetsBackupService _sheets;

  /// Runs a full backup: reuses [existingSpreadsheetId] if given (writing
  /// into the same shared sheet every time), otherwise creates a fresh one
  /// and returns its id/url for the caller to persist.
  Future<FullBackupResult> run(
    GoogleSignInAccount account, {
    String? existingSpreadsheetId,
    String? existingSpreadsheetUrl,
    void Function(String table, int index, int total)? onProgress,
  }) async {
    var spreadsheetId = existingSpreadsheetId;
    var spreadsheetUrl = existingSpreadsheetUrl;
    if (spreadsheetId == null) {
      final created = await _sheets.createBackupSpreadsheet(account);
      spreadsheetId = created.id;
      spreadsheetUrl = created.url;
    }

    final results = <TableBackupResult>[];
    for (var i = 0; i < backupTables.length; i++) {
      final table = backupTables[i];
      onProgress?.call(table, i + 1, backupTables.length);
      try {
        final rows = await AppSupabase.client.from(table).select();
        final headers = rows.isEmpty
            ? const <String>[]
            : rows.first.keys.toList();
        final sheetRows = rows
            .map((row) => headers.map((h) => _cellValue(row[h])).toList())
            .toList();
        await _sheets.writeTable(
          account,
          spreadsheetId: spreadsheetId,
          table: table,
          headers: headers,
          rows: sheetRows,
        );
        results.add(TableBackupResult(table: table, rowCount: rows.length));
      } catch (e) {
        results.add(TableBackupResult(table: table, rowCount: 0, error: e));
      }
    }

    return FullBackupResult(
      spreadsheetId: spreadsheetId,
      spreadsheetUrl: spreadsheetUrl!,
      tableResults: results,
    );
  }

  Object? _cellValue(Object? value) {
    if (value == null) return '';
    if (value is String || value is num || value is bool) return value;
    return jsonEncode(value);
  }
}
