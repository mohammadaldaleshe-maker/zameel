import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart';
import 'theme/app_theme.dart';

import 'screens/comments/comments_screen.dart';
import 'screens/friends/friends_screen.dart';
import 'screens/friends/suggested_colleagues_section.dart';
import 'screens/books/books_screen.dart';
import 'screens/stories/stories_screen.dart';
import 'screens/groups/groups_screen.dart';
import 'screens/graduation/graduation_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/business/business_screen.dart';
import 'screens/campus/campus_screen.dart';
import 'screens/meet/meet_screen.dart';
import 'screens/calls/incoming_call_screen.dart';
import 'screens/jobs/jobs_screen.dart';
import 'screens/calendar/calendar_screen.dart';
import 'screens/ai/ai_screen.dart';
import 'screens/v2/zameel_v2_hub_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/search/search_screen.dart';

import 'screens/auth/welcome_screen.dart';

import 'screens/saved_posts_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/social/zameel_social_studio.dart';
import 'screens/social/public_clips_strip.dart';
import 'screens/chat/contact_calls_screen.dart';
import 'screens/polls_screen.dart';
import 'screens/private_groups_screen.dart';

import 'providers/language_provider.dart';
import 'l10n/translations.dart';
import 'widgets/video_player_widget.dart';
import 'widgets/vertical_autoplay_video_player.dart';
import 'providers/user_provider.dart';
import 'screens/profile/profile_screen.dart';
import 'config.dart';
import 'services/push_notification_service.dart';
import 'services/screen_awake_service.dart';
import 'services/media_cache_service.dart';
import 'services/post_publish_service.dart';
import 'widgets/post_media_gallery.dart';

// ============================================================
// MODULARIZED FEATURES
// Existing Dart library is split into focused part files for
// easier maintenance without changing runtime behavior.
// ============================================================

part 'features/auth_app.dart';
part 'features/university.dart';
part 'features/home_feed.dart';
part 'features/arc_menu.dart';
part 'features/drawer_profile.dart';
part 'features/posts_media.dart';


final GlobalKey<NavigatorState> zameelNavigatorKey = GlobalKey<NavigatorState>();


Future<void> _openZameelDeepLink(Uri uri) async {
  if (uri.scheme != 'zameel') return;

  final nav = zameelNavigatorKey.currentState;
  if (nav == null) return;

  if (uri.host == 'graduation') {
    final parts = uri.pathSegments.where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return;
    final token = uri.queryParameters['token'];
    nav.push(MaterialPageRoute(
      builder: (_) => GraduationBookScreen(
        bookId: parts.first,
        inviteToken: token,
      ),
    ));
    return;
  }

  if (uri.host == 'chat') {
    final conversationId = uri.queryParameters['conversation_id']?.trim() ?? '';
    var partnerId = uri.queryParameters['partner_id']?.trim() ?? '';
    var partnerName = uri.queryParameters['partner_name']?.trim() ?? '';
    if (conversationId.isEmpty) return;

    // Native Android bubbles always include partner_id/name. The fallback lookup
    // keeps older/deferred links usable without weakening chat membership rules.
    if (partnerId.isEmpty) {
      final me = Supabase.instance.client.auth.currentUser?.id;
      if (me != null) {
        try {
          final rows = await Supabase.instance.client
              .from('conversation_members')
              .select('user_id')
              .eq('conversation_id', conversationId)
              .neq('user_id', me)
              .limit(1);
          if (rows.isNotEmpty) partnerId = rows.first['user_id']?.toString() ?? '';
        } catch (_) {}
      }
    }
    if (partnerId.isEmpty) return;

    if (partnerName.isEmpty) {
      try {
        final actor = await Supabase.instance.client
            .from('users')
            .select('name')
            .eq('id', partnerId)
            .maybeSingle();
        partnerName = actor?['name']?.toString().trim() ?? '';
      } catch (_) {}
    }

    nav.push(MaterialPageRoute(
      builder: (_) => ChatDetailScreen(
        conversationId: conversationId,
        partnerId: partnerId,
        partnerName: partnerName.isNotEmpty ? partnerName : 'Colleague',
      ),
    ));
  }
}

Future<void> _initAppLinks() async {
  final links = AppLinks();
  try {
    final initial = await links.getInitialLink();
    if (initial != null) {
      Future<void>.delayed(
        const Duration(milliseconds: 900),
        () => _openZameelDeepLink(initial),
      );
    }
  } catch (_) {}
  links.uriLinkStream.listen(_openZameelDeepLink, onError: (_) {});
}

Future<void> _handlePushNavigationData(Map<String, dynamic> data) async {
  final type = (data['notification_type'] ?? data['type'])?.toString() ?? '';
  await Future<void>.delayed(const Duration(milliseconds: 450));
  final nav = zameelNavigatorKey.currentState;
  if (nav == null) return;

  if (type == 'message') {
    final conversationId = data['conversation_id']?.toString() ?? '';
    var partnerId = (data['sender_id'] ?? data['actor_id'])?.toString() ?? '';
    var partnerName = data['sender_name']?.toString().trim() ?? '';
    if (conversationId.isNotEmpty) {
      final me = Supabase.instance.client.auth.currentUser?.id;
      if (partnerId.isEmpty && me != null) {
        try {
          final rows = await Supabase.instance.client
              .from('conversation_members')
              .select('user_id')
              .eq('conversation_id', conversationId)
              .neq('user_id', me)
              .limit(1);
          if (rows.isNotEmpty) {
            partnerId = rows.first['user_id']?.toString() ?? '';
          }
        } catch (_) {}
      }
      if (partnerId.isNotEmpty && partnerName.isEmpty) {
        try {
          final actor = await Supabase.instance.client
              .from('users')
              .select('name')
              .eq('id', partnerId)
              .maybeSingle();
          partnerName = actor?['name']?.toString().trim() ?? '';
        } catch (_) {}
      }
      if (partnerId.isNotEmpty) {
        nav.push(MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            conversationId: conversationId,
            partnerId: partnerId,
            partnerName: partnerName.isNotEmpty ? partnerName : 'Colleague',
          ),
        ));
        return;
      }
    }
  }

  if (type == 'incoming_video_call' || type == 'incoming_voice_call') {
    final roomId = data['room_id']?.toString() ?? '';
    if (roomId.isEmpty) return;
    final video = data['video'] == true ||
        data['video']?.toString().toLowerCase() == 'true' ||
        type == 'incoming_video_call';
    String callerName = 'Colleague';
    String? callerImage;
    final callerId = data['caller_id']?.toString();
    if (callerId != null && callerId.isNotEmpty) {
      try {
        final actor = await Supabase.instance.client
            .from('users')
            .select('name,profile_image')
            .eq('id', callerId)
            .maybeSingle();
        final name = actor?['name']?.toString().trim();
        if (name != null && name.isNotEmpty) callerName = name;
        callerImage = actor?['profile_image']?.toString();
      } catch (_) {}
    }
    final accepted = await nav.push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => IncomingCallScreen(callerName: callerName, callerImage: callerImage, video: video),
      ),
    );
    if (accepted != true) {
      try {
        await Supabase.instance.client.from('direct_call_sessions').update({
          'status': 'declined',
          'ended_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('room_id', roomId).eq('status', 'ringing');
      } catch (_) {}
      return;
    }
    nav.push(
      MaterialPageRoute(
        builder: (_) => MeetScreen(
          participantName: callerName,
          roomId: roomId,
          startImmediately: true,
          startWithVideo: video,
          isInitiator: false,
        ),
      ),
    );
    return;
  }

  nav.push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ScreenAwakeService.initialize();
  unawaited(MediaCacheService.cleanup());

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: AppTheme.primary,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppTheme.primaryDark,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  await Supabase.initialize(
    url: ZameelConfig.supabaseUrl,
    publishableKey: ZameelConfig.supabasePublishableKey,
  );

  // Firebase must never prevent the core application from opening.
  var firebaseReady = false;
  try {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    firebaseReady = Firebase.apps.isNotEmpty;
    if (firebaseReady) {
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      await PushNotificationService.instance.initialize();
      await PushNotificationService.instance.registerForCurrentUser();
    }
  } catch (error, stack) {
    debugPrint('Firebase initialization skipped: $error');
    debugPrintStack(stackTrace: stack);
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
     ],
     child: const ZameelApp(),
   ),
  );
  if (firebaseReady) {
    await PushNotificationService.instance.setTapHandler(_handlePushNavigationData);
  }
  await _initAppLinks();
 }

// ============================================================
// AUTH GATE
// إدارة جلسة المستخدم وتحديد الشاشة المناسبة
// ============================================================
