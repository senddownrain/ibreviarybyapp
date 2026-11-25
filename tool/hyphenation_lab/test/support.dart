import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const fontFiles = {
  'Literata': ['assets/fonts/Literata-Regular.ttf'],
  'SourceSerif4': ['assets/fonts/SourceSerif4-Regular.ttf'],
  'OldStandardTT': [
    'assets/fonts/OldStandardTT-Regular.ttf',
    'assets/fonts/OldStandardTT-Italic.ttf',
    'assets/fonts/OldStandardTT-Bold.ttf',
  ],
  'Kurale': ['assets/fonts/Kurale-Regular.ttf'],
};

/// Loads the bundled fonts into the test engine (no network, no google_fonts).
Future<void> loadLabFonts() async {
  for (final entry in fontFiles.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      loader.addFont(
        File(path).readAsBytes().then((b) => ByteData.sublistView(b)),
      );
    }
    await loader.load();
  }
}

/// Renders [widget] through the real Flutter render pipeline into a PNG file.
Future<void> savePng(
  WidgetTester tester,
  Widget widget,
  String path, {
  required double width,
  double height = 4000,
  double pixelRatio = 2,
}) async {
  final key = GlobalKey();
  tester.view.physicalSize = Size(width * pixelRatio, height * pixelRatio);
  tester.view.devicePixelRatio = pixelRatio;
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(key: key, child: widget),
      ),
    ),
  );
  await tester.pump();
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });
}
