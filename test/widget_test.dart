// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_app/main.dart';

void main() {
  testWidgets('Hello iPhone smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify our app bar title renders.
    expect(find.text('Hello iPhone!'), findsOneWidget);

    // Verify our iPhone icon and caption render.
    expect(find.byIcon(Icons.phone_iphone), findsOneWidget);
    expect(find.text('This app is running on iOS!'), findsOneWidget);
  });
}
