import 'package:zameel/services/device_session_monitor160.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zameel/services/device_trust160.dart';
import 'package:zameel/screens/security/device_verification160.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const user = '00000000-0000-4000-8000-000000000001';
  var approved = false,
      present = false,
      signup = false,
      fail = false,
      completion = 0,
      sends = 0;
  final calls = <String>[];
  final claims = base64Url
      .encode(utf8.encode(jsonEncode({
        'sub': user,
        'exp': DateTime.now()
                .add(const Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000
      })))
      .replaceAll('=', '');
  Map<String, dynamic> session() => {
        'access_token': 'e30.$claims.sig',
        'refresh_token': 'refresh',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': user,
          'aud': 'authenticated',
          'role': 'authenticated',
          'email': 'owner@example.com',
          'email_confirmed_at': '2026-01-01T00:00:00Z',
          'app_metadata': {},
          'user_metadata': {},
          'created_at': '2026-01-01T00:00:00Z'
        }
      };
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('zameel/device_trust160'),
            (call) async => 'ab' * 32);
    await Supabase.initialize(
        url: 'https://fixture.test',
        anonKey: 'fixture',
        debug: false,
        authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
        httpClient: MockClient((r) async {
          final path = r.url.path.split('/').last;
          calls.add(path);
          dynamic data;
          if (path == 'token')
            data = session();
          else if (path == 'otp') {
            sends++;
            data = {};
          } else if (path == 'verify') {
            data = session();
          } else if (fail) {
            return http.Response(
                jsonEncode({
                  'code': '42501',
                  'message': 'device_verification_required'
                }),
                403,
                request: r,
                headers: {'content-type': 'application/json'});
          } else if (path == 'zameel_device_status160')
            data = {'enabled': true, 'approved': approved};
          else if (path == 'zameel_device_present160')
            data = present;
          else if (path == 'zameel_device_signup160')
            data = signup;
          else if (path == 'zameel_device_challenge160')
            data = '00000000-0000-4000-8000-000000000010';
          else if (path == 'zameel_device_complete160') {
            completion++;
            approved = true;
            data = true;
          } else
            data = [];
          return http.Response(jsonEncode(data), 200,
              headers: {'content-type': 'application/json'}, request: r);
        }));
    await Supabase.instance.client.auth.signInWithPassword(
        email: 'owner@example.com', password: 'fixture-only');
  });
  setUp(() {
    approved = false;
    present = false;
    signup = false;
    fail = false;
    calls.clear();
    DeviceTrust160.approvedUser = null;
  });
  tearDownAll(() async => Supabase.instance.dispose());
  test('unapproved password session cannot mark itself ready', () async {
    expect(await DeviceTrust160.ready(), false);
    expect(DeviceTrust160.approvedUser, isNull);
    expect(calls, contains('zameel_device_present160'));
    expect(calls, contains('zameel_device_signup160'));
  });
  test('trusted proof permits the current account session', () async {
    present = true;
    expect(await DeviceTrust160.ready(), true);
    expect(DeviceTrust160.approvedUser, user);
  });
  test('approved session avoids repeated device presentation', () async {
    approved = true;
    expect(await DeviceTrust160.ready(), true);
    expect(calls, isNot(contains('zameel_device_present160')));
  });
  test('network or permission errors fail closed', () async {
    fail = true;
    await expectLater(
        DeviceTrust160.ready(), throwsA(isA<PostgrestException>()));
    expect(DeviceTrust160.approvedUser, isNull);
  });
  testWidgets(
      'code screen does not send mail until requested and completes verification',
      (tester) async {
    final before = sends, completed = completion;
    var opened = false;
    await tester.pumpWidget(MaterialApp(
        home: DeviceVerification160(onVerified: () => opened = true)));
    expect(sends, before);
    expect(opened, false);
    await tester.tap(find.text('إرسال رمز التحقق'));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump();
    expect(sends, before + 1);
    expect(find.byType(TextField), findsOneWidget);
    expect(opened, false);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('تأكيد الجهاز والدخول'));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump();
    expect(completion, completed + 1);
    expect(opened, true);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('revocation clears a just-approved session before the first poll',
      (tester) async {
    approved = false;
    DeviceTrust160.approvedUser = user;
    await tester.pumpWidget(const MaterialApp(
        home: DeviceSessionMonitor160(child: Text('fixture'))));
    for (var attempt = 0;
        attempt < 50 && Supabase.instance.client.auth.currentUser != null;
        attempt++) {
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
    }
    expect(Supabase.instance.client.auth.currentUser, isNull,
        reason: 'A revoked session must finish sign-out; requests: $calls');
    expect(DeviceTrust160.approvedUser, isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
