import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zameel/services/sponsored_feed.dart';
import 'package:zameel/widgets/sponsored_exposure.dart';

void main() {
  test('unified server order, six-post spacing, deduplication and short feeds',
      () {
    final ordinary = List.generate(18, (i) => <String, dynamic>{'id': 'p$i'});
    final promotions = <Map<String, dynamic>>[
      {'id': 's1'},
      {'id': 's2'},
      {'id': 's1'}
    ];
    final ads = <Map<String, dynamic>>[
      {'id': 'a1'},
      {'id': 'a2'},
      {'id': 'a1'}
    ];
    final order = ['ad:a2', 'post:s2', 'ad:a1', 'post:s1'];
    final feed = arrangeCampaignFeed162(
        [...ordinary, ordinary[0]], promotions, ads,
        order: order);
    final sponsored = feed
        .where((p) =>
            p['_partner_campaign162'] == true || '${p['id']}'.startsWith('s'))
        .toList();
    expect(sponsored.map((p) => p['id']), ['a2', 's2', 'a1']);
    expect(feed[6]['id'], 'a2');
    expect(feed[13]['id'], 's2');
    expect(feed.length, 21);
    expect(arrangeCampaignFeed162([], promotions, ads, order: order).length, 1);
    expect(
        arrangeCampaignFeed162(ordinary, promotions, ads, order: order), feed);
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  final events = <Map<String, dynamic>>[];
  var accepted = false, loseReply = false;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
        url: 'https://fixture.test',
        anonKey: 'fixture',
        debug: false,
        authOptions: const FlutterAuthClientOptions(
            detectSessionInUri: false, autoRefreshToken: false),
        httpClient: MockClient((r) async {
          if (r.url.path.endsWith('/token')) {
            const uid = '00000000-0000-4000-8000-000000000001';
            final claims = base64Url
                .encode(utf8.encode(jsonEncode({
                  'sub': uid,
                  'exp': DateTime.now()
                          .add(const Duration(hours: 1))
                          .millisecondsSinceEpoch ~/
                      1000
                })))
                .replaceAll('=', '');
            return http.Response(
                jsonEncode({
                  'access_token': 'e30.$claims.sig',
                  'refresh_token': 'refresh',
                  'expires_in': 3600,
                  'token_type': 'bearer',
                  'user': {
                    'id': uid,
                    'email': 'viewer@test.com',
                    'created_at': '2026-01-01T00:00:00Z',
                    'app_metadata': {},
                    'user_metadata': {}
                  }
                }),
                200,
                headers: {'content-type': 'application/json'},
                request: r);
          }
          events.add({
            'rpc': r.url.path.split('/').last,
            ...jsonDecode(r.body) as Map<String, dynamic>
          });
          if (loseReply) {
            loseReply = false;
            return http.Response('{"message":"response lost"}', 503,
                headers: {'content-type': 'application/json'}, request: r);
          }
          return http.Response(jsonEncode(accepted), 200,
              headers: {'content-type': 'application/json'}, request: r);
        }));
    await Supabase.instance.client.auth
        .signInWithPassword(email: 'viewer@test.com', password: 'fixture');
  });
  tearDownAll(() => Supabase.instance.dispose());
  for (final partner in [false, true]) {
    testWidgets(
        '${partner ? 'partner' : 'post'} denial keeps card; new visible visit counts separately',
        (tester) async {
      events.clear();
      accepted = false;
      var now = DateTime(2026, 10, 15, 12);
      final controller = ScrollController();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      Supabase.instance.client.auth.stopAutoRefresh();
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: ListView(controller: controller, children: [
        SponsoredExposure(
            postId: 'original-id',
            partner: partner,
            now: () => now,
            child: const SizedBox(
                height: 150, child: Text('campaign stays visible'))),
        const SizedBox(height: 2000),
      ]))));
      Future<void> tick() async {
        now = now.add(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }

      for (var i = 0; i < 5; i++) {
        await tick();
      }
      expect(find.text('campaign stays visible'), findsOneWidget);
      expect(events.length, 1);
      final first = events.single;
      expect(
          first['rpc'],
          partner
              ? 'zameel_record_advertisement162'
              : 'zameel_record_promotion');
      controller.jumpTo(500);
      await tester.pump();
      await tick();
      controller.jumpTo(0);
      await tester.pump();
      accepted = true;
      for (var i = 0; i < 5; i++) {
        await tick();
      }
      expect(events.length, 2);
      expect(events[1]['p_event'], isNot(first['p_event']));
      for (var i = 0; i < 5; i++) {
        await tick();
      }
      expect(events.length, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });
  }
  testWidgets('network retry retains the same event without hiding content',
      (tester) async {
    events.clear();
    accepted = true;
    loseReply = true;
    var now = DateTime(2026, 10, 15, 12);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    Supabase.instance.client.auth.stopAutoRefresh();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SponsoredExposure(
                postId: 'post',
                now: () => now,
                child: const SizedBox(height: 100, child: Text('retained'))))));
    for (var i = 0; i < 10; i++) {
      now = now.add(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(events.length, 2);
    expect(events.first['p_event'], events.last['p_event']);
    expect(find.text('retained'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
