import 'package:flutter_test/flutter_test.dart';
import 'package:gusto_neumorphic/gusto_neumorphic.dart';

/// Relative paint-cost benchmark: animates decoration changes across a grid
/// of concave (gradient) and emboss (negative depth) widgets so every frame
/// exercises decoration lerp, shadow layers, gradient shaders, and the
/// emboss path transforms. Debug-mode timings are only meaningful compared
/// against the same test on another revision of this package.
void main() {
  testWidgets('paint benchmark', (tester) async {
    var depth = 4.0;
    late StateSetter rebuild;

    await tester.pumpWidget(
      NeumorphicApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return GridView.count(
              crossAxisCount: 6,
              children: [
                for (var i = 0; i < 18; i++)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Neumorphic(
                      duration: const Duration(milliseconds: 100),
                      style: NeumorphicStyle(
                        shape: NeumorphicShape.concave,
                        depth: depth,
                        intensity: 0.7,
                      ),
                    ),
                  ),
                for (var i = 0; i < 18; i++)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Neumorphic(
                      duration: const Duration(milliseconds: 100),
                      style: NeumorphicStyle(depth: -depth),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );

    // Warm-up.
    for (var i = 0; i < 30; i++) {
      rebuild(() => depth = depth == 4.0 ? 4.5 : 4.0);
      await tester.pump(const Duration(milliseconds: 16));
    }

    final sw = Stopwatch()..start();
    for (var i = 0; i < 400; i++) {
      rebuild(() => depth = depth == 4.0 ? 4.5 : 4.0);
      await tester.pump(const Duration(milliseconds: 16));
    }
    sw.stop();

    // ignore: avoid_print -- benchmark output
    print('BENCHMARK: 400 animated frames in ${sw.elapsedMilliseconds}ms');
  });

  testWidgets('steady-state repaint benchmark', (tester) async {
    var angle = 0.0;
    late StateSetter rebuild;

    // A rotating sibling (no repaint boundary) dirties the shared layer every
    // frame, forcing all neumorphic painters to repaint with UNCHANGED styles
    // — the scroll-repaint scenario.
    await tester.pumpWidget(
      NeumorphicApp(
        home: Stack(
          children: [
            StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return Transform.rotate(
                  angle: angle,
                  child: const SizedBox(
                    width: 10,
                    height: 10,
                    child: ColoredBox(color: Color(0xFF000000)),
                  ),
                );
              },
            ),
            GridView.count(
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
          ],
        ),
      ),
    );

    for (var i = 0; i < 30; i++) {
      rebuild(() => angle += 0.01);
      await tester.pump(const Duration(milliseconds: 16));
    }

    final sw = Stopwatch()..start();
    for (var i = 0; i < 400; i++) {
      rebuild(() => angle += 0.01);
      await tester.pump(const Duration(milliseconds: 16));
    }
    sw.stop();

    // ignore: avoid_print -- benchmark output
    print('BENCHMARK-STEADY: 400 repaint frames in ${sw.elapsedMilliseconds}ms');
  });
}
