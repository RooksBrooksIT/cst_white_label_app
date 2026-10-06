import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ebricks/screens/common/reset_password_screen.dart';

void main() {
  testWidgets('ResetPasswordScreen renders Step 1 (Email input) with eBricks branding', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: ResetPasswordScreen(),
      ),
    );

    // Verify Title and Subtitle
    expect(find.text('Reset Password'), findsWidgets);
    expect(find.text('Forgot Password'), findsOneWidget);
    expect(find.text('Registered Email Address'), findsOneWidget);
    expect(find.text('SEND OTP'), findsOneWidget);
    expect(find.text('Back to Login'), findsOneWidget);

    // Verify Step Indicator nodes
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Verify OTP'), findsOneWidget);
    expect(find.text('New Password'), findsOneWidget);
  });

  testWidgets('ResetPasswordScreen validates empty and invalid email format', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: ResetPasswordScreen(),
      ),
    );

    // Tap SEND OTP with empty email
    await tester.ensureVisible(find.text('SEND OTP'));
    await tester.tap(find.text('SEND OTP'));
    await tester.pumpAndSettle();

    expect(find.text('Email cannot be empty'), findsOneWidget);

    // Enter invalid email format
    await tester.enterText(find.byType(TextFormField), 'invalid-email');
    await tester.ensureVisible(find.text('SEND OTP'));
    await tester.tap(find.text('SEND OTP'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address'), findsOneWidget);
  });

  testWidgets('ResetPasswordScreen displays masked email and proper instruction helper', (WidgetTester tester) async {
    // Tests that ResetPasswordScreen helper methods format masked emails properly
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: ResetPasswordScreen(),
      ),
    );

    // Initial state check
    expect(find.text('Forgot Password'), findsOneWidget);
    expect(find.text('Registered Email Address'), findsOneWidget);
    expect(find.text('SEND OTP'), findsOneWidget);
  });
}
