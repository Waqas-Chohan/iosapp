// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_app/src/presentation/app.dart';
import 'package:my_first_app/src/presentation/screens/login_screen.dart';

void main() {
  testWidgets('Splash screen shows the logo, then navigates to Login',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Splash screen starts with exactly one logo image.
    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsOneWidget);

    // After the 2.5s splash delay and route transition, Login is shown.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back!'), findsOneWidget);
  });

  testWidgets('Login screen renders fields and the CTA button',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Login'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'test@gym.com');
    expect(find.text('test@gym.com'), findsOneWidget);
  });
}

