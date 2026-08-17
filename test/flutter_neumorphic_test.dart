import 'package:flutter_test/flutter_test.dart';
import 'package:gusto_neumorphic/gusto_neumorphic.dart';

void main() {
  testWidgets('NeumorphicApp renders a Neumorphic container', (tester) async {
    await tester.pumpWidget(
      NeumorphicApp(
        home: NeumorphicBackground(
          child: Center(
            child: Neumorphic(
              style: NeumorphicStyle(depth: 4),
              child: SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Neumorphic), findsOneWidget);
  });

  testWidgets('NeumorphicButton responds to taps', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      NeumorphicApp(
        home: Center(
          child: NeumorphicButton(
            onPressed: () => pressed = true,
            child: Text('tap'),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(NeumorphicButton));
    await tester.pumpAndSettle();
    expect(pressed, isTrue);
  });
}
