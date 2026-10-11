import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'push_notification_service.dart';

final chatRouteObserver = RouteObserver<ModalRoute<dynamic>>();

/// Only a visible, resumed conversation owns this device's short lease.
class ChatVisibilityService {
  static String? conversation;
  static String? _user;
  static Object? _owner;
  static int _revision = 0;
  static Future<void> _pending = Future.value();
  static const _native = MethodChannel('zameel/chat_visibility');
  static bool matches(String? id) =>
      id != null &&
      id == conversation &&
      _user == Supabase.instance.client.auth.currentUser?.id &&
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  static Future<void> _setNative(String? id, String? user) async {
    try {
      await _native
          .invokeMethod<void>('set', {'conversationId': id, 'userId': user});
    } on MissingPluginException {
      /* Web/iOS uses the local push guard. */
    } catch (e) {
      debugPrint('Chat visibility native: $e');
    }
  }

  static void set(Object owner, String? id) {
    if (id == null && !identical(owner, _owner)) return;
    _owner = id == null ? null : owner;
    conversation = id;
    _user = id == null ? null : Supabase.instance.client.auth.currentUser?.id;
    final user = _user;
    final revision = ++_revision;
    // Calls serialize so a delayed heartbeat cannot overwrite a later clear.
    unawaited(_setNative(id, user));
    _pending = _pending.catchError((Object _) {}).then((_) async {
      if (revision != _revision || id != conversation || user != _user) return;
      final token = PushNotificationService.instance.lastToken;
      if (token == null ||
          token.isEmpty ||
          Supabase.instance.client.auth.currentUser == null) return;
      try {
        await Supabase.instance.client
            .rpc('zameel_chat_device_visibility_153', params: {
          'p_token': token,
          'p_conversation': id,
        }).timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('Chat visibility lease: $e');
      }
    });
  }
}
