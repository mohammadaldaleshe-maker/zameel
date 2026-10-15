import 'package:flutter/material.dart';
import 'package:zameel/services/device_session_monitor160.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zameel/services/device_trust160.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const user = '00000000-0000-4000-8000-000000000001',
      sid = '00000000-0000-4000-8000-000000000010';
  final calls = <String>[];
  var firstOtp = false, present = false, serverApproved = false;
  var activeSid = sid;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('zameel/device_trust160'),
            (_) async => 'ab' * 32);
    String claims() => base64Url
        .encode(utf8.encode(jsonEncode({
          'sub': user,
          'session_id': activeSid,
          'exp': DateTime.now()
                  .add(const Duration(hours: 1))
                  .millisecondsSinceEpoch ~/
              1000
        })))
        .replaceAll('=', '');
    await Supabase.initialize(
        url: 'https://fixture.test',
        anonKey: 'fixture',
        debug: false,
        authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
        httpClient: MockClient((request) async {
          final path = request.url.path.split('/').last;
          calls.add(path);
          final data = path == 'token'
              ? {
                  'access_token': 'e30.${claims()}.sig',
                  'refresh_token': 'refresh',
                  'token_type': 'bearer',
                  'expires_in': 3600,
                  'user': {
                    'id': user,
                    'email': 'first@example.com',
                    'email_confirmed_at': '2026-01-01T00:00:00Z',
                    'created_at': '2026-01-01T00:00:00Z',
                    'app_metadata': {},
                    'user_metadata': {}
                  }
                }
              : path == 'zameel_device_status160'
                  ? {'approved': serverApproved}
                  : path == 'zameel_device_present160'
                      ? present
                      : path == 'zameel_device_first_otp161'
                          ? firstOtp
                          : false;
          return http.Response(jsonEncode(data), 200,
              headers: {'content-type': 'application/json'}, request: request);
        }));
    await Supabase.instance.client.auth
        .signInWithPassword(email: 'first@example.com', password: 'fixture');
  });
  setUp(() {
    calls.clear();
    firstOtp = false;
    present = false;
    serverApproved = false;
    activeSid = sid;
    DeviceTrust160.approvedUser = null;
  });
  tearDownAll(() async => Supabase.instance.dispose());
  test('first server-verified OTP enrols without requesting a second email',
      () async {
    firstOtp = true;
    expect(await Future.wait([DeviceTrust160.ready(), DeviceTrust160.ready()]),
        [true, true]);
    expect(
        calls.where((name) => name == 'zameel_device_first_otp161').length, 1);
    expect(calls, isNot(contains('otp')));
    expect(DeviceTrust160.approvedUser, user);
  });
  test('known installation avoids OTP enrolment and email', () async {
    present = true;
    expect(await DeviceTrust160.ready(), true);
    expect(calls, isNot(contains('zameel_device_first_otp161')));
    expect(calls, isNot(contains('otp')));
  });
  test(
      'password-only first installation remains unapproved and never sends unsolicited email',
      () async {
    expect(await DeviceTrust160.ready(), false);
    expect(DeviceTrust160.approvedUser, isNull);
    expect(calls, isNot(contains('otp')));
  });
  testWidgets(
      'a fresh login is not mistaken for revocation of the previous session',
      (tester) async {
    serverApproved = true;
    await tester.runAsync(() async {
      expect(await DeviceTrust160.ready(), true);
    });
    await tester.pumpWidget(const MaterialApp(
        home: DeviceSessionMonitor160(child: Text('SESSION'))));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump();
    DeviceTrust160.approvedUser = null;
    serverApproved = false;
    activeSid = '00000000-0000-4000-8000-000000000011';
    await tester.runAsync(() async {
      await Supabase.instance.client.auth
          .signInWithPassword(email: 'first@example.com', password: 'fixture');
    });
    calls.clear();
    await tester.pump(const Duration(seconds: 16));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump();
    expect(Supabase.instance.client.auth.currentUser?.id, user);
    expect(calls, isNot(contains('logout')));
    expect(DeviceTrust160.approvedUser, isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
