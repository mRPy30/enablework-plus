import 'dart:convert';

import 'package:enablework_plus/screens/fsl_section_guide.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('each guide shows its steps and points to a bundled sign', (
    tester,
  ) async {
    final catalog = jsonDecode(
      await rootBundle.loadString('assets/fsl/catalog.json'),
    ) as List;
    for (final section in GuideSection.values) {
      final sign = catalog.singleWhere((item) => item['label'] == section.sign);
      expect(
        (await rootBundle.load('assets/fsl/${sign["id"]}.mp4')).lengthInBytes,
        greaterThan(0),
      );
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: FslSectionGuide(section))),
      );
      await tester.tap(find.text('FSL guide'));
      await tester.pumpAndSettle();
      expect(find.text('1. ${section.firstStep}'), findsOneWidget);
      expect(find.text('2. ${section.nextStep}'), findsOneWidget);
      expect(find.text(section.sign), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    }
  });
}
