import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zameel/widgets/mention_content158.dart';
import 'package:zameel/widgets/friend_wall158.dart';
import 'package:zameel/widgets/mention_field156.dart';

void main() {
  var allow = false;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
        url: 'https://fixture.test',
        anonKey: 'test',
        debug: false,
        authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
        httpClient: MockClient((request) async {
          final data = request.url.path.endsWith('zameel_mentions_read158')
              ? [
                  {'id': 'friend-id', 'name': 'أسامة'}
                ]
              : request.url.path.endsWith('zameel_member_settings_read158')
                  ? {'can_post': allow, 'birth_date': null}
                  : [];
          return http.Response(jsonEncode(data), 200,
              headers: {'content-type': 'application/json'}, request: request);
        }));
  });
  tearDownAll(() async => Supabase.instance.dispose());
  testWidgets('header names and inline mention links retain ordinary text',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: MentionContent158('مرحبا أنا محمد @أسامة',
                kind: 'post', id: 'post-id', header: true))));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
    expect(find.text('مع '), findsOneWidget);
    expect(find.text('أسامة'), findsOneWidget);
    final rich = tester
        .widgetList<RichText>(find.byType(RichText))
        .firstWhere((w) => w.text.toPlainText() == 'مرحبا أنا محمد @أسامة');
    Iterable<TextSpan> spans(InlineSpan span) sync* {
      if (span is TextSpan) {yield span;for(final child in span.children ?? <InlineSpan>[]) {yield* spans(child);}}
    }
    final links = spans(rich.text).where((span) => span.text == '@أسامة');
    expect(links.single.recognizer, isA<TapGestureRecognizer>());
    expect((links.single.recognizer as TapGestureRecognizer).onTap, isNotNull);
    expect(find.text('@أسامة'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('friend wall composer follows owner permission', (tester) async {
    Future<void> mount(String key) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: FriendWall158(key: ValueKey(key), owner: 'owner'))));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump();
    }

    allow = false;
    await mount('off');
    expect(find.text('اكتب على صفحة صديقك'), findsNothing);
    allow = true;
    await mount('on');
    expect(find.text('اكتب على صفحة صديقك'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  test('everyone is separate from selected account ids', () {
    final c = MentionController156();
    c.selected['everyone'] = 'الجميع';
    c.selected['friend'] = 'أسامة';
    c.text = 'مرحبا @الجميع و @أسامة';
    expect(c.mentionEveryone, true);
    expect(c.mentionIds, ['friend']);
    c.dispose();
  });
}
