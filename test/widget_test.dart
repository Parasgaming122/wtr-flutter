
// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myapp/main.dart';

void main() {
  testWidgets('WTR Lab Reader smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const WtrLabReaderApp());

    // The app starts with a loading indicator while it loads the state.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Wait for the app to finish initializing.
    await tester.pumpAndSettle();

    // After initialization, verify that the main UI components are present.
    expect(find.byType(TabBarWidget), findsOneWidget);
    expect(find.byType(WebViewStack), findsOneWidget);

    // Verify the initial "wtr-lab" tab is present.
    expect(find.text('wtr-lab'), findsOneWidget);

    // Verify the main control buttons are on the screen.
    expect(find.byIcon(Icons.history), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
