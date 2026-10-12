import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zameel/services/background_publish156.dart';
import 'package:zameel/services/post_publish_service.dart';

class TestPath156 extends PathProviderPlatform {
  final String root;
  TestPath156(this.root);
  @override
  Future<String?> getApplicationSupportPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const owner = '00000000-0000-4000-8000-000000000001';
  late Directory temp;
  final posts = <String, Map<String, dynamic>>{};
  bool loseResponse = true;
  int inserts = 0, uploads = 0;
  final requests = <String>[];
  final native = <String>[];
  final failedSignal156 = Completer<void>();
  var stoppedSignal156 = Completer<void>();
  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('zameel-upload156-test');
    PathProviderPlatform.instance = TestPath156(temp.path);
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('com.llfbandit.app_links/events'),
            (call) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('zameel/uploads156'),
            (call) async {
      native.add(call.method);
      if (call.method == 'failed' && !failedSignal156.isCompleted) {
        failedSignal156.complete();
      }
      if (call.method == 'stop' && !stoppedSignal156.isCompleted) {
        stoppedSignal156.complete();
      }
      return null;
    });
    await Supabase.initialize(
        authOptions:
            const FlutterAuthClientOptions(detectSessionInUri: false),
        url: 'https://fixture.test',
        anonKey: 'fixture',
        debug: false,
        httpClient: MockClient((r) async {
          final path = r.url.path;
          requests.add('${r.method} $path');
          Object response = [];
          if (path.endsWith('/auth/v1/token')) {
            response = {
              'access_token':
                  '${base64Url.encode(utf8.encode('{"alg":"none"}'))}.${base64Url.encode(utf8.encode('{"sub":"$owner","exp":4102444800}'))}.test',
              'refresh_token': 'fixture-refresh',
              'expires_in': 3600,
              'token_type': 'bearer',
              'user': {
                'id': owner,
                'aud': 'authenticated',
                'email': 'fixture@example.invalid',
                'created_at': '2026-10-12T00:00:00Z',
                'app_metadata': {},
                'user_metadata': {}
              }
            };
          } else if (path.endsWith('/rest/v1/posts')) {
            if (r.method == 'POST') {
              final row = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
              posts[row['id']] = row;
              inserts++;
              response = [row];
            } else {
              final id = r.url.queryParameters['id']?.replaceFirst('eq.', '');
              if (r.method == 'PATCH') {
                posts[id]!.addAll(
                    Map<String, dynamic>.from(jsonDecode(r.body) as Map));
                if (loseResponse) {
                  loseResponse = false;
                  throw const SocketException(
                      'simulated response lost after commit');
                }
              }
              response = posts[id] == null ? [] : [posts[id]!];
            }
          } else if (path.contains('/storage/v1/object/') &&
              r.method == 'POST') {
            uploads++;
            response = {'Key': 'fixture'};
          }
          if (response is List &&
              response.length == 1 &&
              r.headers.entries.any((e) =>
                  e.key.toLowerCase() == 'accept' &&
                  e.value.contains('object+json'))) response = response.first;
          return http.Response(jsonEncode(response), 200,
              headers: {'content-type': 'application/json'}, request: r);
        }));
    await Supabase.instance.client.auth.signInWithPassword(
        email: 'fixture@example.invalid', password: 'fixture-password');
  });
  tearDownAll(() async {
    await Supabase.instance.dispose();
    await temp.delete(recursive: true);
  });
  Future<void> settle(String id, String state) async {
    for (var i = 0; i < 150; i++) {
      final rows = await BackgroundPublish156.tasks();
      if (rows.any((r) => r['id'] == id && r['state'] == state)) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    fail('task did not reach $state');
  }

  test(
      'durable upload returns before network; lost success response can retry without duplicate post or upload',
      () async {
    final file = File('${temp.path}/image.jpg');
    await file.writeAsBytes([1, 2, 3, 4]);
    final id = await BackgroundPublish156.post(
        text: 'اختبار',
        audience: 'public',
        media: [PickedPostMedia(source: XFile(file.path), byteSize: 4)]);
    final queued = (await BackgroundPublish156.tasks())
        .singleWhere((job) => job['id'] == id);
    final staged = File((queued['files'] as List).single['path'] as String);
    expect(await staged.exists(), true,
        reason: 'The queued file must be persisted at its recorded path');
    expect(await staged.readAsBytes(), [1, 2, 3, 4]);
    expect(staged.parent.path.endsWith(id), true);
    await settle(id, 'error');
    expect(posts[id]?['upload_state156'], 'ready',
        reason:
            'requests: $requests; tasks: ${await BackgroundPublish156.tasks()}');
    expect(inserts, 1);
    expect(uploads, 1);
    expect(native, contains('start'));
    await failedSignal156.future.timeout(const Duration(seconds: 20));
    await stoppedSignal156.future.timeout(const Duration(seconds: 20));
    expect(native, contains('failed'));
    stoppedSignal156 = Completer<void>();
    await BackgroundPublish156.retry(id);
    await settle(id, 'done');
    expect(inserts, 1);
    expect(uploads, 1);
    await stoppedSignal156.future.timeout(const Duration(seconds: 20));
    expect((await BackgroundPublish156.tasks())
        .singleWhere((job) => job['id'] == id)['state'], 'done');
    expect(await staged.parent.exists(), false);
    expect(native, contains('stop'));
  });
  test('queue rejects an oversized image before staging', () async {
    await expectLater(
        BackgroundPublish156.post(text: '', audience: 'public', media: [
          PickedPostMedia(
              source: XFile('${temp.path}/unused.jpg'),
              byteSize: 13 * 1024 * 1024)
        ]),
        throwsStateError);
  });
}
