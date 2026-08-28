import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class DriveFolder {
  const DriveFolder({required this.id, required this.name, this.webViewLink});

  final String id;
  final String name;
  final String? webViewLink;
}

class GoogleDriveService {
  static const _scopes = <String>[
    'https://www.googleapis.com/auth/drive.readonly',
  ];

  static Future<void>? _initFuture;

  Future<void> _ensureInitialized() {
    return _initFuture ??= GoogleSignIn.instance
        .initialize(
          clientId: kIsWeb
              ? dotenv.env['GOOGLE_WEB_CLIENT_ID']
              : dotenv.env['GOOGLE_IOS_CLIENT_ID'],
          serverClientId: kIsWeb ? null : dotenv.env['GOOGLE_WEB_CLIENT_ID'],
        )
        .catchError((Object e) {
          _initFuture = null;
          throw e;
        });
  }

  /// Whether this platform supports calling [signInInteractively] directly
  /// (mobile). On web this is false — the user must sign in via the
  /// rendered Google button instead (see [authenticationEvents]).
  Future<bool> get supportsDirectSignIn async {
    await _ensureInitialized();
    return GoogleSignIn.instance.supportsAuthenticate();
  }

  Stream<GoogleSignInAuthenticationEvent> get authenticationEvents =>
      GoogleSignIn.instance.authenticationEvents;

  /// Tries to sign in without any user interaction (reuses an existing
  /// session/cookie). Returns null if a sign-in prompt is required.
  Future<GoogleSignInAccount?> attemptSilentSignIn() async {
    await _ensureInitialized();
    final lightweight = GoogleSignIn.instance
        .attemptLightweightAuthentication();
    return lightweight != null ? await lightweight : null;
  }

  /// Mobile-only: opens the native account picker directly.
  Future<GoogleSignInAccount> signInInteractively() async {
    await _ensureInitialized();
    return GoogleSignIn.instance.authenticate(scopeHint: _scopes);
  }

  Future<drive.DriveApi> _driveApiFor(GoogleSignInAccount account) async {
    final authorization =
        await account.authorizationClient.authorizationForScopes(_scopes) ??
        await account.authorizationClient.authorizeScopes(_scopes);
    final client = authorization.authClient(scopes: _scopes);
    return drive.DriveApi(client);
  }

  Future<List<DriveFolder>> listSubfolders(
    GoogleSignInAccount account,
    String parentFolderId,
  ) async {
    final api = await _driveApiFor(account);
    final result = await api.files.list(
      q: "'$parentFolderId' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false",
      $fields: 'files(id,name,webViewLink)',
      orderBy: 'name',
      spaces: 'drive',
      pageSize: 200,
    );
    return (result.files ?? [])
        .map(
          (f) => DriveFolder(
            id: f.id ?? '',
            name: f.name ?? '',
            webViewLink: f.webViewLink,
          ),
        )
        .where((f) => f.id.isNotEmpty)
        .toList();
  }
}
