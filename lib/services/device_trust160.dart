import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Trust is scoped to both the account and the current Auth session on the server.
class DeviceTrust160 {
  static String? _approvedUser161;
  static String? _approvedSession161;
  static String? get approvedUser =>
      _approvedUser161 != null && _approvedSession161 == _sessionKey161()
          ? _approvedUser161
          : null;
  static set approvedUser(String? user) {
    _approvedUser161 = user;
    _approvedSession161 = user == null ? null : _sessionKey161();
  }

  static String? get sessionIdentity161 => _sessionKey161();
  static const _channel = MethodChannel('zameel/device_trust160');
  static final Map<String, String> _temporary = {};
  static SupabaseClient get db => Supabase.instance.client;
  static String get label =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? 'هاتف Android'
          : kIsWeb
              ? 'متصفح زميل'
              : 'جهاز زميل';
  static Future<String> proof(String user) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final value =
          await _channel.invokeMethod<String>('proof', {'userId': user});
      if (value == null || !RegExp(r'^[a-f0-9]{64}$').hasMatch(value)) {
        throw StateError('secure_device_storage_unavailable');
      }
      return value;
    }
    // No insecure persistent fallback. Other platforms verify again after restart.
    return _temporary.putIfAbsent(user, () {
      final random = Random.secure();
      return List.generate(
              32, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
          .join();
    });
  }

  static Future<Map<String, dynamic>> status() async =>
      Map<String, dynamic>.from(await db.rpc('zameel_device_status160') as Map);
  static Future<bool>? _readyFlight161;
  static String? _flightKey161;
  static String? _sessionKey161() {
    final session = db.auth.currentSession;
    if (session == null) return null;
    try {
      final claims = jsonDecode(utf8.decode(base64Url.decode(
          base64Url.normalize(session.accessToken.split('.')[1])))) as Map;
      final sid = claims['session_id'];
      if (sid != null) return '${session.user.id}:$sid';
    } catch (_) {/* A malformed token must never grant trust. */}
    return session.accessToken;
  }

  static Future<bool> ready() {
    final key = _sessionKey161();
    if (key == null) return Future.value(false);
    if (_flightKey161 == key && _readyFlight161 != null)
      return _readyFlight161!;
    _flightKey161 = key;
    final work = _ready161(key);
    _readyFlight161 = work;
    return work.whenComplete(() {
      if (identical(_readyFlight161, work)) {
        _readyFlight161 = null;
        _flightKey161 = null;
      }
    });
  }

  static Future<bool> _ready161(String sessionKey) async {
    final user = db.auth.currentUser?.id;
    if (user == null) return false;
    final current = await status();
    if (db.auth.currentUser?.id != user || _sessionKey161() != sessionKey)
      return false;
    if (current['approved'] == true) {
      approvedUser = user;
      return true;
    }
    final secret = await proof(user);
    if (db.auth.currentUser?.id != user || _sessionKey161() != sessionKey)
      return false;
    final accepted =
        await db.rpc('zameel_device_present160', params: {'p_secret': secret});
    final enrolled = accepted == true ||
        await db.rpc('zameel_device_signup160',
                params: {'p_secret': secret, 'p_label': label}) ==
            true ||
        await db.rpc('zameel_device_first_otp161',
                params: {'p_secret': secret, 'p_label': label}) ==
            true;
    final confirmed = enrolled || (await status())['approved'] == true;
    final ready = db.auth.currentUser?.id == user &&
        _sessionKey161() == sessionKey &&
        confirmed;
    if (ready) approvedUser = user;
    return ready;
  }

  static Future<String> sendCode() async {
    final user = db.auth.currentUser;
    if (user == null ||
        (user.emailConfirmedAt == null && user.phoneConfirmedAt == null))
      throw StateError('confirmed_contact_required');
    final secret = await proof(user.id);
    if (db.auth.currentUser?.id != user.id) throw StateError('account_changed');
    final challenge = await db.rpc('zameel_device_challenge160',
        params: {'p_secret': secret, 'p_label': label});
    if (db.auth.currentUser?.id != user.id) throw StateError('account_changed');
    await db.auth.signInWithOtp(
        email: user.emailConfirmedAt != null ? user.email : null,
        phone: user.emailConfirmedAt == null ? user.phone : null,
        shouldCreateUser: false);
    return challenge.toString();
  }

  static Future<void> verify(
      String contact, String challenge, String code, String userId,
      {bool phone = false}) async {
    if (db.auth.currentUser?.id != userId) throw StateError('account_changed');
    final secret = await proof(userId);
    final result = await db.auth.verifyOTP(
        email: phone ? null : contact,
        phone: phone ? contact : null,
        token: code.trim(),
        type: phone ? OtpType.sms : OtpType.email);
    if (result.user?.id != userId || db.auth.currentUser?.id != userId)
      throw StateError('account_changed');
    final done = await db.rpc('zameel_device_complete160',
        params: {'p_challenge': challenge, 'p_secret': secret});
    if (done != true) throw StateError('device_verification_required');
    approvedUser = userId;
  }
}
