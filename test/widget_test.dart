import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trouble_sarthi/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TroubleSarthiApp());

    // Verify that the app builds without errors
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}