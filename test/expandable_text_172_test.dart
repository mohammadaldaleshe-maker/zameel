import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zameel/widgets/expandable_text171.dart';

Widget _host(String text) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          child: ExpandableText171(
            text: text,
            collapsedLines: 3,
            builder: (context, lines, overflow) =>
                Text(text, maxLines: lines, overflow: overflow),
          ),
        ),
      ),
    );

void main() {
  testWidgets('short text shows no button', (tester) async {
    await tester.pumpWidget(_host('نص قصير'));
    expect(find.byKey(const ValueKey('expandableTextToggle171')), findsNothing);
    expect(find.text('Show more'), findsNothing);
  });

  testWidgets('long text can be expanded and folded again', (tester) async {
    final long = List.filled(12, 'كلمة طويلة جدا').join(' ');
    await tester.pumpWidget(_host(long));
    expect(find.text('Show more'), findsOneWidget);
    expect(tester.widget<Text>(find.text(long)).maxLines, 3);
    await tester.tap(find.byKey(const ValueKey('expandableTextToggle171')));
    await tester.pump();
    expect(find.text('Show less'), findsOneWidget);
    expect(tester.widget<Text>(find.text(long)).maxLines, isNull);
    await tester.tap(find.byKey(const ValueKey('expandableTextToggle171')));
    await tester.pump();
    expect(find.text('Show more'), findsOneWidget);
  });
}
