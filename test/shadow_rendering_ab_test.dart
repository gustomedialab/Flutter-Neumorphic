import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gusto_neumorphic/gusto_neumorphic.dart';

/// Renders the same neumorphic widget with the legacy saveLayer renderer and
/// the clip-based renderer, then compares the rasterized pixels. This is the
/// safety net for the saveLayer rework: the two renderers must be visually
/// indistinguishable.
void main() {
  Future<Uint8List> capture(WidgetTester tester, Widget child) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      NeumorphicApp(
        debugShowCheckedModeBanner: false,
        home: Center(
          child: RepaintBoundary(
            key: key,
            child: Container(
              color: const Color(0xFFDDDDDD),
              padding: const EdgeInsets.all(40),
              child: SizedBox(width: 160, height: 120, child: child),
            ),
          ),
        ),
      ),
    );
    // Let the implicit style animation settle so both captures are static.
    await tester.pump(const Duration(milliseconds: 300));
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image =
        (await tester.runAsync(() => boundary.toImage(pixelRatio: 1.0)))!;
    final data = await tester.runAsync(() async =>
        (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!);
    return data!.buffer.asUint8List();
  }

  Future<void> compareRenderers(
      WidgetTester tester, String label, Widget child) async {
    NeumorphicShadowRendering.useClipPath = false;
    final legacy = await capture(tester, child);
    NeumorphicShadowRendering.useClipPath = true;
    final clip = await capture(tester, child);

    expect(legacy.length, clip.length);
    var maxDelta = 0;
    var over2 = 0;
    var over8 = 0;
    for (var i = 0; i < legacy.length; i++) {
      final d = (legacy[i] - clip[i]).abs();
      if (d > maxDelta) maxDelta = d;
      if (d > 2) over2++;
      if (d > 8) over8++;
    }
    final channels = legacy.length;
    // ignore: avoid_print -- comparison report
    print('AB[$label]: maxDelta=$maxDelta, '
        '>2: ${(100 * over2 / channels).toStringAsFixed(3)}%, '
        '>8: ${(100 * over8 / channels).toStringAsFixed(3)}%');

    // Tolerances: blur/AA may differ by a hair at edges, but any real
    // rendering break shows up as large areas of large deltas.
    expect(100 * over8 / channels, lessThan(0.5),
        reason: '$label: too many significantly different pixels');
  }

  testWidgets('flat roundrect depth 4', (tester) async {
    await compareRenderers(
      tester,
      'flat-roundrect',
      Neumorphic(style: NeumorphicStyle(depth: 4)),
    );
  });

  testWidgets('concave circle depth 6', (tester) async {
    await compareRenderers(
      tester,
      'concave-circle',
      Neumorphic(
        style: NeumorphicStyle(
          depth: 6,
          shape: NeumorphicShape.concave,
          boxShape: NeumorphicBoxShape.circle(),
        ),
      ),
    );
  });

  testWidgets('convex stadium, bottomRight light', (tester) async {
    await compareRenderers(
      tester,
      'convex-stadium-br',
      Neumorphic(
        style: NeumorphicStyle(
          depth: 5,
          shape: NeumorphicShape.convex,
          lightSource: LightSource.bottomRight,
          boxShape: NeumorphicBoxShape.stadium(),
        ),
      ),
    );
  });

  testWidgets('emboss roundrect depth -4', (tester) async {
    await compareRenderers(
      tester,
      'emboss-roundrect',
      Neumorphic(style: NeumorphicStyle(depth: -4)),
    );
  });

  testWidgets('emboss circle depth -6, topRight light', (tester) async {
    await compareRenderers(
      tester,
      'emboss-circle-tr',
      Neumorphic(
        style: NeumorphicStyle(
          depth: -6,
          lightSource: LightSource.topRight,
          boxShape: NeumorphicBoxShape.circle(),
        ),
      ),
    );
  });

  testWidgets('text flat depth 4 (opaque fill fast path)', (tester) async {
    await compareRenderers(
      tester,
      'text-flat',
      Center(
        child: NeumorphicText(
          'Harbour',
          style: NeumorphicStyle(depth: 4, color: const Color(0xFF4A4A4A)),
          textStyle: NeumorphicTextStyle(
              fontSize: 36, fontWeight: FontWeight.w800),
        ),
      ),
    );
  });

  testWidgets('text concave gradient', (tester) async {
    await compareRenderers(
      tester,
      'text-concave',
      Center(
        child: NeumorphicText(
          'Gusto',
          style: NeumorphicStyle(
            depth: 5,
            shape: NeumorphicShape.concave,
            color: const Color(0xFF4A4A4A),
            surfaceIntensity: 0.6,
          ),
          textStyle: NeumorphicTextStyle(
              fontSize: 36, fontWeight: FontWeight.w800),
        ),
      ),
    );
  });

  testWidgets('text translucent fill (legacy shadow fallback)',
      (tester) async {
    await compareRenderers(
      tester,
      'text-translucent',
      Center(
        child: NeumorphicText(
          'Ghost',
          style: NeumorphicStyle(depth: 4, color: const Color(0x804A4A4A)),
          textStyle: NeumorphicTextStyle(
              fontSize: 36, fontWeight: FontWeight.w800),
        ),
      ),
    );
  });

  testWidgets('high intensity emboss stadium', (tester) async {
    await compareRenderers(
      tester,
      'emboss-stadium-hi',
      Neumorphic(
        style: NeumorphicStyle(
          depth: -8,
          intensity: 0.9,
          boxShape: NeumorphicBoxShape.stadium(),
        ),
      ),
    );
  });
}
