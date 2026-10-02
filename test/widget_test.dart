import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ebricks/widgets/glass_card.dart';

void main() {
  testWidgets('GlassCard renders child and title without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GlassCard(
            title: 'Test Card Title',
            child: Text('Test Child Text'),
          ),
        ),
      ),
    );

    expect(find.text('Test Card Title'), findsOneWidget);
    expect(find.text('Test Child Text'), findsOneWidget);
  });
}
