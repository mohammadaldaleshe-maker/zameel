import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeIncomingCallService {
  static const _channel = MethodChannel('zameel/incoming_calls');
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static Future<void> setUser(String? id) async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('setUser', {'userId': id});
    } catch (_) {}
  }

  static Future<void> dismiss(String room) async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('dismiss', {'roomId': room});
    } catch (_) {}
  }

  static Future<void> finishDecline() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('finishDecline');
    } catch (_) {}
  }

  static Future<bool> canFullScreen() async {
    if (!supported) return true;
    try {
      return await _channel.invokeMethod<bool>('canFullScreen') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> requestFullScreen() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('requestFullScreen');
    } catch (_) {}
  }
}
