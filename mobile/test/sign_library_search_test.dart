import 'package:enablework_plus/screens/sign_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('offline greetings are searchable in Filipino and English', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: SignLibrary(greetings: true)),
    );
    final field = find.byType(TextField);
    for (final query in ['  SaLaMat  ', 'thank you']) {
      await tester.enterText(field, query);
      await tester.pumpAndSettle();
      expect(find.text('Thank you'), findsOneWidget);
      expect(find.text('Salamat'), findsOneWidget);
      expect(find.byType(ListTile), findsOneWidget);
    }
    await tester.enterText(field, 'Mabilis');
    await tester.pumpAndSettle();
    expect(find.text('No signs match this search.'), findsOneWidget);
  });
}
