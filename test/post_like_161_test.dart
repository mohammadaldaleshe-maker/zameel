import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zameel/services/post_like161.dart';

void main() {
  const uid = '00000000-0000-4000-8000-000000000001';
  const pid = '00000000-0000-4000-8000-000000000002';
  late SupabaseClient db;
  var exists = false, deny = false, failCount = false, loseReply = false;
  var writes = 0;
  final requests = <http.Request>[];
  setUp(() async {
    exists = false;
    deny = false;
    failCount = false;
    loseReply = false;
    writes = 0;
    requests.clear();
    db = SupabaseClient('https://fixture.test', 'fixture',
        httpClient: MockClient((r) async {
      requests.add(r);
      Object? data;
      var status = 200;
      if (r.url.path.endsWith('/token')) {
        final claims = base64Url
            .encode(utf8.encode(jsonEncode({
              'sub': uid,
              'exp': DateTime.now()
                      .add(const Duration(hours: 1))
                      .millisecondsSinceEpoch ~/
                  1000,
            })))
            .replaceAll('=', '');
        data = {
          'access_token': 'e30.$claims.sig',
          'refresh_token': 'r',
          'expires_in': 3600,
          'token_type': 'bearer',
          'user': {
            'id': uid,
            'email': 'test@example.com',
            'created_at': '2026-01-01T00:00:00Z',
            'app_metadata': {},
            'user_metadata': {}
          }
        };
      } else if (r.url.path.endsWith('/likes')) {
        if (r.method == 'GET') {
          data = exists
              ? [
                  {'post_id': pid}
                ]
              : [];
        } else if (deny) {
          status = 403;
          data = {'message': 'permission denied', 'code': '42501'};
        } else {
          if (r.method == 'POST') {
            expect(r.url.queryParameters['on_conflict'], 'user_id,post_id');
            expect(
                r.headers['prefer'], contains('resolution=ignore-duplicates'));
            expect(jsonDecode(r.body), {'user_id': uid, 'post_id': pid});
            data = exists
                ? []
                : [
                    {'user_id': uid}
                  ];
            if (!exists) writes++;
            exists = true;
            if (loseReply) {
              loseReply = false;
              status = 503;
              data = {'message': 'response lost after commit'};
            }
          } else {
            expect(r.url.queryParameters['user_id'], 'eq.$uid');
            expect(r.url.queryParameters['post_id'], 'eq.$pid');
            data = exists
                ? [
                    {'user_id': uid}
                  ]
                : [];
            if (exists) writes++;
            exists = false;
          }
        }
      } else {
        if (failCount) {
          status = 500;
          data = {'message': 'refresh failed'};
        } else {
          data = [
            {'likes_count': exists ? 8 : 7}
          ];
        }
      }
      return http.Response(jsonEncode(data), status,
          headers: {'content-type': 'application/json'}, request: r);
    }));
    await db.auth
        .signInWithPassword(email: 'test@example.com', password: 'fixture');
  });
  tearDown(() => db.dispose());
  test('existing promoted like is loaded before display', () async {
    exists = true;
    final posts = <Map<String, dynamic>>[
      {'id': pid},
      {'id': 'other'}
    ];
    await hydratePostLikes161(db, uid, posts);
    expect(posts[0]['liked'], true);
    expect(posts[1]['liked'], false);
  });
  test('like and repeated like produce one write and authoritative count',
      () async {
    final first =
        await setPostLike161(db, userId: uid, postId: pid, liked: true);
    final retry =
        await setPostLike161(db, userId: uid, postId: pid, liked: true);
    expect(first.changed, true);
    expect(retry.changed, false);
    expect(first.count, 8);
    expect(retry.displayCount(999, liked: true), 8);
    expect(first.displayCount(7, liked: true), 8);
    expect(retry.displayCount(8, liked: true), 8);
    expect(writes, 1);
  });
  test('unlike and retry delete only the current pair once', () async {
    exists = true;
    final first =
        await setPostLike161(db, userId: uid, postId: pid, liked: false);
    final retry =
        await setPostLike161(db, userId: uid, postId: pid, liked: false);
    expect(first.changed, true);
    expect(retry.changed, false);
    expect(retry.displayCount(7, liked: false), 7);
    expect(writes, 1);
  });
  test('failed count refresh cannot undo a committed or repeated like',
      () async {
    failCount = true;
    final first =
        await setPostLike161(db, userId: uid, postId: pid, liked: true);
    final retry =
        await setPostLike161(db, userId: uid, postId: pid, liked: true);
    expect(first.displayCount(7, liked: true), 8);
    expect(retry.displayCount(8, liked: true), 8);
  });
  test('write permission failure is surfaced and cannot count as success',
      () async {
    deny = true;
    await expectLater(setPostLike161(db, userId: uid, postId: pid, liked: true),
        throwsA(isA<PostgrestException>()));
    expect(exists, false);
    expect(writes, 0);
  });
  test('retry after lost success response keeps one like', () async {
    loseReply = true;
    await expectLater(setPostLike161(db, userId: uid, postId: pid, liked: true),
        throwsA(isA<PostgrestException>()));
    expect(exists, true);
    final retry =
        await setPostLike161(db, userId: uid, postId: pid, liked: true);
    expect(retry.changed, false);
    expect(retry.count, 8);
    expect(writes, 1);
  });
  test('foreign account identity cannot reach a write', () async {
    await expectLater(
        setPostLike161(db, userId: 'foreign', postId: pid, liked: true),
        throwsStateError);
    expect(requests.where((r) => r.url.path.endsWith('/likes')), isEmpty);
  });
}
