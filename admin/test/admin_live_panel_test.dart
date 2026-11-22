import 'package:enablework_admin/screens/admin_live_panel.dart';
import 'package:enablework_admin/services/admin_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeRepository implements AdminDataSource {
  bool fail = false;
  @override
  Future<Map<String, int>> counts() async => {'PWD job seekers': 0};
  @override
  Future<List<Map<String, dynamic>>> records(String section, int page) async {
    if (fail) throw StateError('private database detail');
    return [];
  }
}

void main() {
  testWidgets('live empty results do not show fixture records', (tester) async {
    final repository = FakeRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminLivePanel(
            repository: repository,
            section: 'companies',
            title: 'Companies',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No matching records'), findsOneWidget);
    expect(find.textContaining('do not have accounts'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Next'))
          .onPressed,
      isNull,
    );
  });
  testWidgets('failures show retry and do not leak database errors', (
    tester,
  ) async {
    final repository = FakeRepository()..fail = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminLivePanel(
            repository: repository,
            section: 'jobs',
            title: 'Jobs',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Records could not be loaded'), findsOneWidget);
    expect(find.textContaining('private database detail'), findsNothing);
    repository.fail = false;
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('No matching records'), findsOneWidget);
  });
}
