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

  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(
      clientId: kIsWeb
          ? dotenv.env['GOOGLE_WEB_CLIENT_ID']
          : dotenv.env['GOOGLE_IOS_CLIENT_ID'],
      serverClientId: kIsWeb ? null : dotenv.env['GOOGLE_WEB_CLIENT_ID'],
    );
    _initialized = true;
  }

  Future<drive.DriveApi> _authorizedDriveApi() async {
    await _ensureInitialized();
    final signIn = GoogleSignIn.instance;

    GoogleSignInAccount? account;
    final lightweight = signIn.attemptLightweightAuthentication();
    if (lightweight != null) {
      account = await lightweight;
    }
    account ??= await signIn.authenticate(scopeHint: _scopes);

    GoogleSignInClientAuthorization authorization =
        await account.authorizationClient.authorizationForScopes(_scopes) ??
        await account.authorizationClient.authorizeScopes(_scopes);

    final client = authorization.authClient(scopes: _scopes);
    return drive.DriveApi(client);
  }

  Future<List<DriveFolder>> listSubfolders(String parentFolderId) async {
    final api = await _authorizedDriveApi();
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
