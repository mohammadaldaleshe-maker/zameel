import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zameel/services/external_share156.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const id = 'af393dd7-e8fa-4928-af70-a5c80fe89a9e';
  final requests = <http.Request>[];
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
        url: 'https://fixture.test',
        anonKey: 'fixture',
        debug: false,
        authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
              jsonEncode(request.url.path.endsWith('zameel_share_story161')
                  ? ['new-story']
                  : []),
              200,
              headers: {'content-type': 'application/json'},
              request: request);
        }));
  });
  tearDownAll(() async => Supabase.instance.dispose());
  test('share request identity is bounded random UUID v4', () {
    final ids = List.generate(100, (_) => shareRequestId161());
    expect(ids.toSet().length, 100);
    for (final value in ids)
      expect(
          value,
          matches(RegExp(
              r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$')));
  });
  testWidgets(
      'story option uses source identity and never raw media URL or profile action',
      (tester) async {
    var profile = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => showContentShare157(context,
                            id: id, kind: 'clip', onProfile: () async {
                          profile++;
                        }),
                    child: const Text('SHARE'))))));
    await tester.tap(find.text('SHARE'));
    await tester.pumpAndSettle();
    expect(find.text('على صفحتي الشخصية'), findsOneWidget);
    expect(find.text('المشاركة إلى حالتي'), findsOneWidget);
    expect(find.text('المشاركة خارج التطبيق'), findsOneWidget);
    expect(find.text('نسخ الرابط'), findsOneWidget);
    await tester.tap(find.text('المشاركة إلى حالتي'));
    await tester.pumpAndSettle();
    final request = requests
        .singleWhere((r) => r.url.path.endsWith('zameel_share_story161'));
    final body = jsonDecode(request.body) as Map;
    expect(body['p_kind'], 'clip');
    expect(body['p_id'], id);
    expect(body.keys.toSet(), {'p_kind', 'p_id', 'p_request'});
    expect(profile, 0);
    expect(find.text('تمت المشاركة إلى حالتك'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
