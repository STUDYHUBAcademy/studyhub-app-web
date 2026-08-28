import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;

import 'google_auth.dart';

class CreatedSpreadsheet {
  const CreatedSpreadsheet({required this.id, required this.url});

  final String id;
  final String url;
}

/// Writes a full snapshot of the database into a Google Sheet — one tab per
/// table, each call clearing and rewriting that tab from scratch. Used by
/// the manual "نسخ احتياطي الآن" backup, kept independent of Supabase so a
/// repeat of the TRUNCATE incident that wiped most of the database doesn't
/// take the backup down with it.
class GoogleSheetsBackupService {
  static const _scopes = <String>[
    'https://www.googleapis.com/auth/spreadsheets',
  ];

  Future<void> _ensureInitialized() => ensureGoogleSignInInitialized();

  Future<bool> get supportsDirectSignIn async {
    await _ensureInitialized();
    return GoogleSignIn.instance.supportsAuthenticate();
  }

  Stream<GoogleSignInAuthenticationEvent> get authenticationEvents =>
      GoogleSignIn.instance.authenticationEvents;

  Future<GoogleSignInAccount?> attemptSilentSignIn() async {
    await _ensureInitialized();
    final lightweight = GoogleSignIn.instance
        .attemptLightweightAuthentication();
    return lightweight != null ? await lightweight : null;
  }

  Future<GoogleSignInAccount> signInInteractively() async {
    await _ensureInitialized();
    return GoogleSignIn.instance.authenticate(scopeHint: _scopes);
  }

  Future<sheets.SheetsApi> _sheetsApiFor(GoogleSignInAccount account) async {
    final authorization =
        await account.authorizationClient.authorizationForScopes(_scopes) ??
        await account.authorizationClient.authorizeScopes(_scopes);
    final client = authorization.authClient(scopes: _scopes);
    return sheets.SheetsApi(client);
  }

  Future<CreatedSpreadsheet> createBackupSpreadsheet(
    GoogleSignInAccount account,
  ) async {
    final api = await _sheetsApiFor(account);
    final created = await api.spreadsheets.create(
      sheets.Spreadsheet(
        properties: sheets.SpreadsheetProperties(
          title: 'StudyHub Academy — نسخة احتياطية',
        ),
      ),
    );
    final id = created.spreadsheetId!;
    return CreatedSpreadsheet(
      id: id,
      url:
          created.spreadsheetUrl ??
          'https://docs.google.com/spreadsheets/d/$id',
    );
  }

  /// Overwrites the tab named [table] with [headers] + [rows], creating the
  /// tab first if this is its first backup.
  Future<void> writeTable(
    GoogleSignInAccount account, {
    required String spreadsheetId,
    required String table,
    required List<String> headers,
    required List<List<Object?>> rows,
  }) async {
    final api = await _sheetsApiFor(account);
    await _ensureSheetExists(api, spreadsheetId, table);
    await api.spreadsheets.values.clear(
      sheets.ClearValuesRequest(),
      spreadsheetId,
      "'$table'",
    );
    if (headers.isEmpty) return;
    await api.spreadsheets.values.update(
      sheets.ValueRange(values: [headers, ...rows]),
      spreadsheetId,
      "'$table'!A1",
      valueInputOption: 'RAW',
    );
  }

  Future<void> _ensureSheetExists(
    sheets.SheetsApi api,
    String spreadsheetId,
    String title,
  ) async {
    final spreadsheet = await api.spreadsheets.get(spreadsheetId);
    final exists = (spreadsheet.sheets ?? []).any(
      (s) => s.properties?.title == title,
    );
    if (exists) return;
    await api.spreadsheets.batchUpdate(
      sheets.BatchUpdateSpreadsheetRequest(
        requests: [
          sheets.Request(
            addSheet: sheets.AddSheetRequest(
              properties: sheets.SheetProperties(title: title),
            ),
          ),
        ],
      ),
      spreadsheetId,
    );
  }
}
