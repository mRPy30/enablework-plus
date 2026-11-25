import 'dart:async';

import 'package:enablework_plus/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'offline library works before sign in and survives reconnection',
    (tester) async {
      final network = StreamController<bool>();
      addTearDown(network.close);
      await tester.pumpWidget(MainApp(connectivity: network.stream));
      network.add(false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Offline FSL'));
      await tester.pumpAndSettle();
      expect(find.text('FSL dictionary'), findsOneWidget);
      network.add(true);
      await tester.pumpAndSettle();
      expect(find.text('Offline FSL'), findsNothing);
      expect(find.text('FSL dictionary'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('FSL dictionary'), findsNothing);
    },
  );
}
