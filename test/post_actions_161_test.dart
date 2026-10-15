import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zameel/widgets/post_action161.dart';

void main() {
  testWidgets(
      'one icon per action with counts, unchanged color, tooltip and independent likes list',
      (tester) async {
    var taps = 0, counts = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Row(children: [
      PostAction161(
          icon: Icons.favorite,
          label: 'إعجاب',
          color: Colors.cyan,
          countText: '2',
          onPressed: () => taps++,
          onCountTap: () => counts++),
      PostAction161(
          icon: Icons.comment_outlined,
          label: 'التعليقات',
          color: Colors.blue,
          countText: '0',
          onPressed: () {}),
      PostAction161(
          icon: Icons.bookmark_outline,
          label: 'حفظ',
          color: Colors.blue,
          onPressed: () {}),
      PostAction161(
          icon: Icons.share_outlined,
          label: 'مشاركة',
          color: Colors.blue,
          countText: '0',
          onPressed: () {}),
    ]))));
    expect(find.text('إعجاب'), findsNothing);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(tester.widget<Icon>(find.byIcon(Icons.favorite)).color, Colors.cyan);
    await tester.tap(find.byIcon(Icons.favorite));
    expect(taps, 1);
    await tester.tap(find.text('2'));
    expect(counts, 1);
    expect(taps, 1);
    await tester.longPress(find.byIcon(Icons.favorite));
    await tester.pumpAndSettle();
    expect(find.text('إعجاب'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
