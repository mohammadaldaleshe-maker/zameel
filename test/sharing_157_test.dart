import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zameel/services/external_share156.dart';
import 'package:zameel/services/header_occasion_156.dart';
import 'package:zameel/services/post_presentation157.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const id = 'af393dd7-e8fa-4928-af70-a5c80fe89a9e';
  var requests = 0;
  var audience = 'public';
  String? copied;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData')
        copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    await Supabase.initialize(
        url: 'https://fixture.test',
        anonKey: 'fixture',
        debug: false,
        authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
        httpClient: MockClient((r) async {
          requests++;
          return http.Response(
              jsonEncode(r.url.path.contains('/rest/v1/posts')
                  ? {
                      'id': id,
                      'audience': audience,
                      'is_hidden': false,
                      'upload_state156': 'ready',
                      'user_id': id
                    }
                  : r.url.path.contains('/rest/v1/users')
                      ? {'account_privacy': 'public'}
                      : {}),
              200,
              headers: {'content-type': 'application/json'},
              request: r);
        }));
  });
  tearDownAll(() async {
    await Supabase.instance.dispose();
  });
  test('links use only canonical public routes and bounded identities', () {
    expect(publicContentLink157('post', id), 'https://zameeljo.com/s/post/$id');
    expect(publicContentLink157('clip', id), 'https://zameeljo.com/s/clip/$id');
    expect(() => publicContentLink157('user', id), throwsArgumentError);
    expect(
        () => publicContentLink157('post', '../private'), throwsArgumentError);
    expect(
        completedMediaPost157({
          'type': 'video',
          'upload_state156': 'ready',
          'video_url': null,
          'media_items': []
        }),
        false);
  });
  testWidgets(
      'one bottom share menu separates profile sharing from external actions',
      (tester) async {
    var shared = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => showContentShare157(context, id: id,
                            onProfile: () async {
                          shared++;
                        }),
                    child: const Text('مشاركة'))))));
    final before = requests;
    await tester.tap(find.text('مشاركة'));
    await tester.pumpAndSettle();
    expect(find.text('على صفحتي الشخصية'), findsOneWidget);
    expect(find.text('المشاركة خارج التطبيق'), findsOneWidget);
    expect(find.text('نسخ الرابط'), findsOneWidget);
    await tester.tap(find.text('على صفحتي الشخصية'));
    await tester.pumpAndSettle();
    expect(shared, 1);
    expect(requests, before);
    expect(copied, isNull);
  });
  testWidgets('copy checks visibility and never posts a profile share',
      (tester) async {
    var shared = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => showContentShare157(context, id: id,
                            onProfile: () async {
                          shared++;
                        }),
                    child: const Text('مشاركة'))))));
    await tester.tap(find.text('مشاركة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('نسخ الرابط'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(copied, 'https://zameeljo.com/s/post/$id');
    expect(shared, 0);
    copied = null;
    audience = 'friends';
    await tester.tap(find.text('مشاركة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('نسخ الرابط'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(copied, isNull);
    expect(shared, 0);
    audience = 'public';
  });
  testWidgets('narrow header retains full brand without overflow',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: Center(
                child: SizedBox(width: 48, child: HeaderOccasion156())))));
    await tester.pump();
    expect(find.text('Zameel'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
