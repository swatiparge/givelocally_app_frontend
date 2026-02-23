// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sample_app/main.dart';

void main() {
  testWidgets('App launches and shows home screen', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SampleApp());

    // Verify that the app title is displayed
    expect(find.text('Google Maps Plugin'), findsOneWidget);

    // Verify that demo buttons are present
    expect(find.text('Unified Map View'), findsOneWidget);
    expect(find.text('Location Picker'), findsOneWidget);

    // Verify that key features section is displayed
    expect(find.text('Key Features:'), findsOneWidget);
  });
}
