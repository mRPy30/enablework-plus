import 'dart:io';
import 'dart:ui' as ui;

import 'package:enablework_plus/main.dart';
import 'package:enablework_plus/widgets/brand_identity.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('branded startup and setup render without account access', (
    tester,
  ) async {
    const output = String.fromEnvironment('BRAND_PREVIEW_DIR');
    const fonts = String.fromEnvironment('BRAND_FONT_DIR');
    if (fonts.isNotEmpty) {
      await tester.runAsync(() async {
        final font = FontLoader('Roboto')
          ..addFont(
            File('$fonts/roboto-regular.ttf')
                .readAsBytes()
                .then(ByteData.sublistView),
          );
        await font.load();
      });
    }
    tester.view.physicalSize = const Size(430, 930);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final entry in <String, Widget>{
      'startup': const BrandSplash(),
      'setup': const MainApp(),
    }.entries) {
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: key, child: entry.value));
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage('assets/branding/enablework-plus-logo.png'),
          tester.element(find.byType(BrandIdentity)),
        );
      });
      await tester.pumpAndSettle();
      expect(find.byType(BrandIdentity), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (output.isNotEmpty) {
        final render =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await render.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('$output/enablework-plus-app-${entry.key}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
  });

  testWidgets('brand identity fits narrow screens with large system text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const MainApp());
    await tester.pumpAndSettle();
    expect(find.byType(BrandIdentity), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
