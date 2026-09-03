import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import 'google_auth.dart';

class DriveFolder {
  const DriveFolder({required this.id, required this.name, this.webViewLink});

  final String id;
  final String name;
  final String? webViewLink;
}

class DriveItem {
  const DriveItem({
    required this.id,
    required this.name,
    required this.isFolder,
    this.webViewLink,
    this.mimeType,
  });

  final String id;
  final String name;
  final bool isFolder;
  final String? webViewLink;
  final String? mimeType;
}

const _folderMimeType = 'application/vnd.google-apps.folder';

class GoogleDriveService {
  static const _scopes = <String>[
    'https://www.googleapis.com/auth/drive.readonly',
  ];

  Future<void> _ensureInitialized() => ensureGoogleSignInInitialized();

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
      q: "'$parentFolderId' in parents and mimeType='$_folderMimeType' and trashed=false",
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

  /// Like [listSubfolders] but also includes individual files (e.g. a
  /// lecture PDF), each flagged via [DriveItem.isFolder] — used by pickers
  /// that need to let the owner select a specific file, not just a folder.
  Future<List<DriveItem>> listFolderContents(
    GoogleSignInAccount account,
    String parentFolderId,
  ) async {
    final api = await _driveApiFor(account);
    final result = await api.files.list(
      q: "'$parentFolderId' in parents and trashed=false",
      $fields: 'files(id,name,webViewLink,mimeType)',
      orderBy: 'folder,name',
      spaces: 'drive',
      pageSize: 200,
    );
    return (result.files ?? [])
        .map(
          (f) => DriveItem(
            id: f.id ?? '',
            name: f.name ?? '',
            isFolder: f.mimeType == _folderMimeType,
            webViewLink: f.webViewLink,
            mimeType: f.mimeType,
          ),
        )
        .where((f) => f.id.isNotEmpty)
        .toList();
  }

  /// The raw OAuth access token for the Drive-readonly scope, to hand to a
  /// trusted backend (an Edge Function) that needs to fetch file content
  /// itself rather than going through this client.
  Future<String> accessTokenFor(GoogleSignInAccount account) async {
    final authorization =
        await account.authorizationClient.authorizationForScopes(_scopes) ??
        await account.authorizationClient.authorizeScopes(_scopes);
    return authorization.accessToken;
  }
}
