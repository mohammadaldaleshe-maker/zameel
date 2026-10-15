import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zameel/services/advertising_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var exists = false, denied = false, writes = 0;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
        url: 'https://fixture.test',
        anonKey: 'fixture',
        debug: false,
        authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
        httpClient: MockClient((r) async {
          Object? data;
          var status = 200;
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
            data = {
              'access_token': 'e30.$claims.sig',
              'refresh_token': 'r',
              'expires_in': 3600,
              'token_type': 'bearer',
              'user': {
                'id': uid,
                'email': 'fixture@test.com',
                'created_at': '2026-01-01T00:00:00Z',
                'app_metadata': {},
                'user_metadata': {}
              }
            };
          } else if (r.url.path.endsWith('/advertisement_likes')) {
            if (denied) {
              status = 403;
              data = {'code': '42501', 'message': 'denied'};
            } else if (r.method == 'POST') {
              expect(r.url.queryParameters['on_conflict'],
                  'advertisement_id,user_id');
              expect(r.headers['prefer'], contains('ignore-duplicates'));
              data = exists
                  ? []
                  : [
                      {'user_id': 'me'}
                    ];
              if (!exists) writes++;
              exists = true;
            } else {
              data = exists
                  ? [
                      {'user_id': 'me'}
                    ]
                  : [];
              if (exists) writes++;
              exists = false;
            }
          } else {
            data = [
              {'likes_count': exists ? 4 : 3}
            ];
          }
          return http.Response(jsonEncode(data), status,
              headers: {'content-type': 'application/json'}, request: r);
        }));
    await Supabase.instance.client.auth
        .signInWithPassword(email: 'fixture@test.com', password: 'fixture');
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() {
    exists = false;
    denied = false;
    writes = 0;
  });
  test('partner like is idempotent and does not duplicate its count', () async {
    final one = await AdvertisingService.setLiked('ad', liked: true);
    final two = await AdvertisingService.setLiked('ad', liked: true);
    expect(one.changed, true);
    expect(two.changed, false);
    expect(two.count, 4);
    expect(writes, 1);
  });
  test('partner unlike is scoped and repeatable', () async {
    exists = true;
    final one = await AdvertisingService.setLiked('ad', liked: false);
    final two = await AdvertisingService.setLiked('ad', liked: false);
    expect(one.changed, true);
    expect(two.changed, false);
    expect(two.count, 3);
    expect(writes, 1);
  });
  test('partner permission failure stays an error', () async {
    denied = true;
    await expectLater(AdvertisingService.setLiked('ad', liked: true),
        throwsA(isA<PostgrestException>()));
    expect(writes, 0);
  });
}
