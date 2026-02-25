import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myapp/main.dart';

void main() {
  testWidgets('SuperBett smoke test', (WidgetTester tester) async {
    // ✅ CORREGIDO: MyApp → SuperBettApp
    await tester.pumpWidget(const SuperBettApp());

    expect(find.text('SUPERBETT POS'), findsOneWidget);
  });
}
