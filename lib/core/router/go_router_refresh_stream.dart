import 'dart:async';

import 'package:flutter/foundation.dart';

/// Bridges a [Stream] (Supabase's auth state changes) into a [Listenable]
/// so go_router re-evaluates its `redirect` whenever auth state changes.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
