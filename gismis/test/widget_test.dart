import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gismis/app/app.dart';

void main() {
  testWidgets('GismisApp widget can be instantiated', (tester) async {
    // This test verifies that the GismisApp widget can be created
    // without throwing any errors during instantiation.
    //
    // Note: We don't pump the widget because it triggers network calls
    // and timers that are tested separately in integration tests.
    // This is a smoke test to ensure the app widget is properly defined.

    expect(() => const GismisApp(), returnsNormally);
    expect(const GismisApp(), isA<Widget>());
  });
}
