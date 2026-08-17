import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gusto_neumorphic/gusto_neumorphic.dart';

/// Rasterization benchmark for the two shadow renderers. Unlike a pump-only
/// benchmark, RepaintBoundary.toImage actually rasterizes the layer tree, so
/// the cost of saveLayer's offscreen passes is included. Compare the two
/// printed numbers; absolute values are only meaningful relative to each
/// other on the same machine.
void main() {
  Future<int> benchmark(WidgetTester tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      NeumorphicApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: key,
          child: GridView.count(
            crossAxisCount: 6,
            children: [
              for (var i = 0; i < 18; i++)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Neumorphic(
                    style: NeumorphicStyle(
                      shape: NeumorphicShape.concave,
                      depth: 4,
                      intensity: 0.7,
                    ),
                  ),
                ),
              for (var i = 0; i < 18; i++)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Neumorphic(style: NeumorphicStyle(depth: -4)),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;

    return (await tester.runAsync<int>(() async {
      // Warm-up.
      for (var i = 0; i < 5; i++) {
        (await boundary.toImage()).dispose();
      }
      final sw = Stopwatch()..start();
      for (var i = 0; i < 60; i++) {
        (await boundary.toImage()).dispose();
      }
      sw.stop();
      return sw.elapsedMilliseconds;
    }))!;
  }

  testWidgets('raster benchmark: legacy saveLayer renderer', (tester) async {
    NeumorphicShadowRendering.useClipPath = false;
    final ms = await benchmark(tester);
    // ignore: avoid_print -- benchmark output
    print('RASTER[legacy-saveLayer]: 60 rasterizations in ${ms}ms');
    NeumorphicShadowRendering.useClipPath = true;
  });

  testWidgets('raster benchmark: clip renderer', (tester) async {
    NeumorphicShadowRendering.useClipPath = true;
    final ms = await benchmark(tester);
    // ignore: avoid_print -- benchmark output
    print('RASTER[clip]: 60 rasterizations in ${ms}ms');
  });
}
