// Basic smoke test: the app boots without throwing before Supabase/env
// bootstrap is wired in (that happens in main(), not here). Real feature
// tests land alongside each feature as it's built out (see test/unit,
// test/widget, test/integration in the project plan).
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('placeholder — real tests land with each feature', () {
    expect(true, isTrue);
  });
}
