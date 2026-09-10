import 'dart:convert';
import 'dart:ui' as ui;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  debugPrint('Zameel background push: ${message.data}');
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel =
      AndroidNotificationChannel(
    'zameel_high_importance',
    'Zameel notifications',
    description:
        'Notifications for messages, colleagues, comments and other Zameel activity.',
    importance: Importance.max,
  );

  bool _ready = false;
  String? _lastToken;

  bool get isReady => _ready;
  String? get lastToken => _lastToken;

  Future<void> initialize() async {
    if (_ready) return;

    try {
      await Firebase.initializeApp();
      _messaging = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings();
      await _local.initialize(
        settings: const InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: _onLocalNotificationResponse,
      );

      final androidLocal = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidLocal?.createNotificationChannel(_channel);
      await androidLocal?.requestNotificationsPermission();

      final messaging = _messaging;
      if (messaging == null) {
        throw StateError('Firebase Messaging is unavailable after Firebase initialization.');
      }

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint(
        'Zameel push authorization: ${settings.authorizationStatus.name}',
      );

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        await _handleTapData(initialMessage.data);
      }

      messaging.onTokenRefresh.listen((token) async {
        await _saveToken(token);
      });

      await registerForCurrentUser();
      _ready = true;
      debugPrint('Zameel push service ready');
    } catch (e, st) {
      // Push must never prevent the core app from opening.
      debugPrint('Zameel push initialization skipped: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  Future<void> registerForCurrentUser() async {
    if (!_ready && Firebase.apps.isEmpty) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final enabled = (await Supabase.instance.client
              .from('users')
              .select('notifications_enabled')
              .eq('id', user.id)
              .maybeSingle())?['notifications_enabled'];
      if (enabled == false) {
        await unregisterCurrentDevice();
        return;
      }

      final messaging = _messaging;
      if (messaging == null) return;
      final token = await messaging.getToken();
      if (token != null) await _saveToken(token);
    } catch (e) {
      debugPrint('Could not register Zameel push token: $e');
    }
  }

  Future<void> unregisterCurrentDevice() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final messaging = _messaging;
      if (messaging == null) return;
      final token = await messaging.getToken();
      if (token != null) {
        await Supabase.instance.client
            .from('push_device_tokens')
            .delete()
            .eq('user_id', user.id)
            .eq('token', token);
      }
    } catch (_) {}
  }

  Future<void> _saveToken(String token) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || token.isEmpty) return;

    _lastToken = token;
    final platform = defaultTargetPlatform.name;
    final locale = ui.PlatformDispatcher.instance.locale.languageCode;

    try {
      await Supabase.instance.client.from('push_device_tokens').upsert(
        {
          'user_id': user.id,
          'token': token,
          'platform': platform,
          'locale': locale,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'token',
      );
      debugPrint('Zameel push token registered for ${user.id}');
    } catch (e) {
      debugPrint('Could not save push token: $e');
    }
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ??
        message.data['title']?.toString() ??
        'Zameel';
    final body = notification?.body ?? message.data['body']?.toString() ?? '';

    await _local.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'zameel_high_importance',
          'Zameel notifications',
          channelDescription: 'Notifications for Zameel activity.',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    _handleTapData(message.data);
  }

  void _onLocalNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final data = Map<String, dynamic>.from(
        jsonDecode(payload) as Map,
      );
      _handleTapData(data);
    } catch (_) {}
  }

  Future<void> _handleTapData(Map<String, dynamic> data) async {
    // Keep tap data available for future deep-link routing. The in-app
    // notification center remains the canonical destination today.
    debugPrint('Zameel notification tapped: $data');
  }
}
