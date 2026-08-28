import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';

Future<void>? _initFuture;

/// Shared across every Google-API-backed service (Drive, Sheets backup...)
/// so `GoogleSignIn.instance.initialize` — a singleton itself — only ever
/// runs once no matter how many services call this.
Future<void> ensureGoogleSignInInitialized() {
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
