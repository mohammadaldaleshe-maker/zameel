import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zameel/widgets/compact_post.dart';
import 'package:zameel/widgets/verified_badge.dart';

void main() {
  testWidgets('compact posts use 85 percent width and preserve accessible text',
      (tester) async {
    double? scale;
    await tester.pumpWidget(MaterialApp(
        home: Center(
            child: SizedBox(
                width: 400,
                child: MediaQuery(
                    data:
                        const MediaQueryData(textScaler: TextScaler.linear(2)),
                    child: CompactPost(child: Builder(builder: (context) {
                      scale = MediaQuery.textScalerOf(context).scale(20);
                      return const SizedBox(
                          key: ValueKey('postContent'),
                          height: 100,
                          child: Text('A readable post'));
                    })))))));
    expect(tester.getSize(find.byKey(const ValueKey('postContent'))).width,
        closeTo(340, .01));
    expect(scale, 34);
    expect(find.byType(Card), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('expired or unpaid verification never shows a badge',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Row(children: [
      VerifiedBadge(expiresAt: null),
      VerifiedBadge(expiresAt: '2000-01-01T00:00:00Z')
    ])));
    expect(find.byIcon(Icons.verified), findsNothing);
    await tester.pumpWidget(const MaterialApp(
        home: VerifiedBadge(expiresAt: '2100-01-01T00:00:00Z')));
    expect(find.byIcon(Icons.verified), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
