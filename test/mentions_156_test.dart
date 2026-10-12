import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zameel/widgets/mention_field156.dart';

void main() {
  final searches = <String>[];
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://fixture.test', anonKey: 'fixture', debug: false,
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
      httpClient: MockClient((r) async {
        searches.add(jsonDecode(r.body)['p_query'] as String);
        return http.Response(jsonEncode([
          {'id':'first','name':'أحمد'}, {'id':'second','name':'سارة'}
        ]), 200, request:r, headers:{'content-type':'application/json'});
      }),
    );
  });
  tearDownAll(() async => Supabase.instance.dispose());
  testWidgets('search and select several colleagues; removing text removes its mention', (tester) async {
    final controller = MentionController156();
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:MentionTextField156(controller:controller))));
    Future<void> search(String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.pump(const Duration(milliseconds:250));
      await tester.runAsync(() async => Future<void>.delayed(const Duration(milliseconds:20)));
      await tester.pump();
    }
    await search('@أ');
    expect(searches.last, 'أ');
    await tester.tap(find.text('أحمد')); await tester.pump();
    await search('${controller.text}@سا');
    await tester.tap(find.text('سارة')); await tester.pump();
    expect(controller.mentionIds, ['first','second']);
    await tester.enterText(find.byType(TextField), '@سارة فقط');
    expect(controller.mentionIds, ['second']);
    await tester.pumpWidget(const SizedBox()); controller.dispose();
  });
}
