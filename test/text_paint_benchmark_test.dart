import 'package:flutter_test/flutter_test.dart';
import 'package:gusto_neumorphic/gusto_neumorphic.dart';

/// Steady-state repaint benchmark for NeumorphicText: a rotating sibling
/// dirties the layer every frame so the text painters repaint with UNCHANGED
/// styles. Before the paragraph-rebuild gate, every repaint rebuilt and laid
/// out 7 paragraphs per widget.
void main() {
  testWidgets('text steady-state repaint benchmark', (tester) async {
    var angle = 0.0;
    late StateSetter rebuild;

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
            Column(
              children: [
                for (var i = 0; i < 10; i++)
                  NeumorphicText(
                    'Harbour City $i',
                    style: NeumorphicStyle(
                      depth: 4,
                      color: const Color(0xFF4A4A4A),
                      shape: i.isEven
                          ? NeumorphicShape.concave
                          : NeumorphicShape.flat,
                    ),
                    textStyle: NeumorphicTextStyle(fontSize: 22),
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
    print('TEXT-STEADY: 400 repaint frames in ${sw.elapsedMilliseconds}ms');
  });
}
