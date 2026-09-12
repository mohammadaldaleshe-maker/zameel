import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart';
import 'theme/app_theme.dart';

import 'screens/comments/comments_screen.dart';
import 'screens/friends/friends_screen.dart';
import 'screens/books/books_screen.dart';
import 'screens/stories/stories_screen.dart';
import 'screens/groups/groups_screen.dart';
import 'screens/graduation/graduation_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/business/business_screen.dart';
import 'screens/campus/campus_screen.dart';
import 'screens/meet/meet_screen.dart';
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
import 'screens/polls_screen.dart';
import 'screens/private_groups_screen.dart';

import 'providers/language_provider.dart';
import 'l10n/translations.dart';
import 'widgets/video_player_widget.dart';
import 'providers/user_provider.dart';
import 'screens/profile/profile_screen.dart';
import 'config.dart';
import 'services/push_notification_service.dart';

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


Future<void> _openGraduationDeepLink(Uri uri) async {
  final nav = zameelNavigatorKey.currentState;
  if (nav == null || uri.scheme != 'zameel' || uri.host != 'graduation') return;
  final parts = uri.pathSegments.where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return;
  final token = uri.queryParameters['token'];
  nav.push(MaterialPageRoute(builder: (_) => GraduationBookScreen(bookId: parts.first, inviteToken: token)));
}

Future<void> _initAppLinks() async {
  final links = AppLinks();
  try {
    final initial = await links.getInitialLink();
    if (initial != null) {
      Future<void>.delayed(const Duration(milliseconds: 900), () => _openGraduationDeepLink(initial));
    }
  } catch (_) {}
  links.uriLinkStream.listen(_openGraduationDeepLink, onError: (_) {});
}

Future<void> _handlePushNavigationData(Map<String, dynamic> data) async {
  final type = (data['notification_type'] ?? data['type'])?.toString() ?? '';
  await Future<void>.delayed(const Duration(milliseconds: 450));
  final nav = zameelNavigatorKey.currentState;
  if (nav == null) return;

  if (type == 'incoming_video_call' || type == 'incoming_voice_call') {
    final roomId = data['room_id']?.toString() ?? '';
    if (roomId.isEmpty) return;
    final video = data['video'] == true ||
        data['video']?.toString().toLowerCase() == 'true' ||
        type == 'incoming_video_call';
    String callerName = 'Colleague';
    final callerId = data['caller_id']?.toString();
    if (callerId != null && callerId.isNotEmpty) {
      try {
        final actor = await Supabase.instance.client
            .from('users')
            .select('name')
            .eq('id', callerId)
            .maybeSingle();
        final name = actor?['name']?.toString().trim();
        if (name != null && name.isNotEmpty) callerName = name;
      } catch (_) {}
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

  // Push notifications are optional at startup: if Firebase is not configured
  // yet, the rest of Zameel still opens normally.
  await PushNotificationService.instance.initialize();
  await PushNotificationService.instance.registerForCurrentUser();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
     ],
     child: const ZameelApp(),
   ),
  );
  await PushNotificationService.instance.setTapHandler(_handlePushNavigationData);
  await _initAppLinks();
 }

// ============================================================
// AUTH GATE
// إدارة جلسة المستخدم وتحديد الشاشة المناسبة
// ============================================================
