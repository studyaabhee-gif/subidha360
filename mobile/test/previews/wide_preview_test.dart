import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subidha360/core/theme/app_theme.dart';
import 'package:subidha360/features/jobs/presentation/job_map.dart';

import 'screens_preview_test.dart' show loadFonts, pumpScene, scenes;

/// Very wide windows, such as a large monitor or a zoomed-out browser, where
/// photos used to be cropped to thin strips or hidden behind cards.
void main() {
  final skip = Platform.environment['PREVIEW'] != '1';
  setUpAll(() async {
    mapTilesEnabled = false;
    if (!skip) await loadFonts();
  });
  for (final name in [
    '01_landing',
    '02_services',
    '06_become_provider',
    '03_service_detail',
  ]) {
    final scene = scenes.where((s) => s.name == name).firstOrNull;
    if (scene == null) continue;
    for (final width in [1920.0, 3200.0]) {
      testWidgets('wide $width $name', skip: skip, (tester) async {
        await pumpScene(
          tester,
          scene,
          theme: AppTheme.light(),
          size: Size(width, 1400),
          dpr: 1,
          decodeImages: true,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('out/wide/${width.toInt()}-$name.png'),
        );
      });
    }
  }
}
