import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zameel/services/secure_media_service.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('Zameel 075 private social discovery contracts', () {
    test('Insijam is opt-in and private by default', () {
      final sql = _read('supabase/migrations/075_lamma_social_discovery.sql');
      final screen = _read('lib/screens/social/lamma_screen.dart');
      final profile = _read('lib/screens/profile/profile_screen.dart');

      expect(sql, contains('enabled boolean not null default false'));
      expect(sql, contains('social_profile_self'));
      expect(sql, isNot(contains('social_profile_public')));
      expect(sql, contains("decision in ('like','pass')"));
      expect(sql, contains('revoke all on function public.get_social_discovery_candidates'));
      expect(screen, contains("'enabled':true"));
      expect(screen, contains("'enabled':false"));
      expect(screen, contains("matched=await db.rpc('react_social_discovery'"));
      expect(profile, isNot(contains('social_discovery_profiles')));
    });

    test('Lamma and Insijam remain separate experiences', () {
      final screen = _read('lib/screens/social/lamma_screen.dart');
      expect(screen, contains('TabController(length:2'));
      expect(screen, contains('join_social_lamma'));
      expect(screen, contains('get_social_discovery_candidates'));
      expect(screen, contains('Adults 18+ only'));
    });
  });

  group('Zameel 072 publishing regression contracts', () {
    test('home photo and video shortcuts remain multi-select', () {
      final home = _read('lib/features/home_feed.dart');

      expect(
        home,
        contains('media.addAll(await PostPublishService.pickMultipleImages())'),
      );
      expect(
        home,
        contains('media.addAll(await PostPublishService.pickMultipleVideos())'),
      );
      expect(
        home,
        contains("await _createPost('', audience: audience, media: media);"),
      );
    });

    test('profile photo and video posts remain multi-select', () {
      final profile = _read('lib/screens/profile/profile_screen.dart');

      expect(profile, contains('PostPublishService.pickMultipleImages()'));
      expect(profile, contains('PostPublishService.pickMultipleVideos()'));
      expect(profile, contains('PostPublishService.publishPost('));
    });

    test('native picker supports image, video and mixed multi-selection', () {
      final publisher = _read('lib/services/post_publish_service.dart');

      expect(publisher, contains('ImagePicker().pickMultiImage('));
      expect(publisher, contains('ImagePicker().pickMultiVideo('));
      expect(publisher, contains('ImagePicker().pickMultipleMedia('));
      expect(publisher, contains('static const int maxMediaItems = 10;'));
      expect(publisher, contains("'media_items': items"));
      expect(publisher, contains('final items = uploaded.map((e) => e.dbItem)'));
    });

    test('post size guard is evaluated before the upload loop', () {
      final publisher = _read('lib/services/post_publish_service.dart');
      final validationCall = publisher.indexOf('_validateSelection(selected);');
      final uploadLoop = publisher.indexOf(
        'for (var index = 0; index < selected.length; index++)',
      );
      final guard = publisher.indexOf('selectedBytes > maxPostMediaBytes');

      expect(validationCall, greaterThanOrEqualTo(0));
      expect(uploadLoop, greaterThan(validationCall));
      expect(guard, greaterThanOrEqualTo(0));
      expect(publisher, contains('static void _validateSelection(List<PickedPostMedia> selected)'));
    });
  });

  group('Zameel 073 floating bubble regression contracts', () {
    test('manifest keeps real overlay and foreground-service declarations', () {
      final manifest = _read('android/app/src/main/AndroidManifest.xml');

      expect(manifest, contains('android.permission.SYSTEM_ALERT_WINDOW'));
      expect(manifest, contains('android.permission.FOREGROUND_SERVICE'));
      expect(
        manifest,
        contains('android.permission.FOREGROUND_SERVICE_SPECIAL_USE'),
      );
      expect(manifest, contains('android:name=".ZameelOverlayService"'));
      expect(manifest, contains('android:foregroundServiceType="specialUse"'));
    });

    test('receiver preserves both overlay and notification fallback paths', () {
      final receiver = _read(
        'android/app/src/main/kotlin/com/zameel/app/ZameelBubbleReceiver.kt',
      );
      final overlay = _read(
        'android/app/src/main/kotlin/com/zameel/app/ZameelOverlayService.kt',
      );

      expect(receiver, contains('ZameelOverlayService.showFromPush'));
      expect(receiver, contains('postConversationFallback'));
      expect(receiver, contains('super.onReceive(context, intent)'));
      expect(receiver, contains('MainActivity.isVisible'));
      expect(receiver, isNot(contains('ActivityManager.getMyMemoryState')));
      expect(overlay, contains('TYPE_APPLICATION_OVERLAY'));
      expect(overlay, contains('postFallbackNotification'));
      expect(overlay, contains('.authority("chat")'));
      expect(overlay, contains('startForeground(SERVICE_NOTIFICATION_ID, messageNotification)'));
      expect(overlay, contains('ACTION_SHOW_BROADCAST'));
      expect(overlay, contains('Context.RECEIVER_NOT_EXPORTED'));
      expect(overlay, contains('return START_NOT_STICKY'));
      expect(receiver, contains('val deliveredToHost = ZameelOverlayService.showFromPush'));
      expect(overlay, contains('Could not start message bubble service from push'));
      expect(overlay, contains('PREF_OVERLAY_VERIFIED'));
      expect(overlay, contains('R.raw.zameel_bubble_thunder'));
      expect(overlay, isNot(contains('buildHostNotification')));
      expect(overlay, isNot(contains('Chat bubbles are ready')));
      expect(overlay, isNot(contains('ACTION_HOST')));
      expect(receiver, contains('Notification.BubbleMetadata.Builder(shortcutId)'));
      // Android 10 uses the legacy channel bubble opt-in; Android 11+ is user/system controlled.
      expect(receiver, contains('if (Build.VERSION.SDK_INT == Build.VERSION_CODES.Q)'));
      expect(receiver, contains('setAllowBubbles(true)'));
      expect(receiver, isNot(contains('setAutoExpandBubble(true)')));
    });

    test('overlay permission remains recoverable after declining or revocation', () {
      final activity = _read(
        'android/app/src/main/kotlin/com/zameel/app/MainActivity.kt',
      );

      expect(activity, contains('ACTION_MANAGE_OVERLAY_PERMISSION'));
      expect(activity, contains('overlayPromptedThisProcess'));
      expect(activity, contains('var isVisible: Boolean = false'));
      expect(activity, contains('override fun onStart()'));
      expect(activity, contains('override fun onResume()'));
      expect(activity, contains('override fun onStop()'));
      expect(activity, contains('ZameelOverlayService.hideBubbleAndStop(this'));
      expect(activity, isNot(contains('ZameelOverlayService.ensureHostRunning(this)')));
      expect(activity, isNot(contains('scheduleOverlaySelfTestIfNeeded')));
      expect(activity, isNot(contains('ZameelOverlayService.runSetupSelfTest(this)')));
      expect(activity, contains('ACTION_APP_NOTIFICATION_BUBBLE_SETTINGS'));
      expect(activity, contains('bubblePreference'));
    });

    test('cold-start chat deep links wait for the Flutter navigator', () {
      final main = _read('lib/main.dart');

      expect(main, contains('Future<NavigatorState?> _waitForZameelNavigator()'));
      expect(main, contains('final nav = await _waitForZameelNavigator();'));
      expect(main, isNot(contains('const Duration(milliseconds: 900)')));
    });
  });

  group('Zameel 072 media-egress regression contracts', () {
    test('full video playback never streams and prefetches the same URL together', () {
      final vertical = _read('lib/widgets/vertical_autoplay_video_player.dart');
      final stories = _read('lib/screens/stories/stories_screen.dart');
      final clips = _read('lib/screens/social/public_clips_strip.dart');

      expect(vertical, contains('downloadIfMissing: true'));
      expect(vertical, isNot(contains('MediaCacheService.prefetch(<String>[rawUrl]')));
      expect(stories, isNot(contains('MediaCacheService.prefetch(<String>[path]')));
      expect(clips, isNot(contains('MediaCacheService.prefetch(<String>[widget.url]')));
    });

    test('story and clip trays do not eagerly download batches of full videos', () {
      final stories = _read('lib/screens/stories/stories_screen.dart');
      final clips = _read('lib/screens/social/public_clips_strip.dart');

      expect(stories, isNot(contains('limit: 8')));
      expect(clips, isNot(contains('limit: 6')));
      expect(stories, contains('MediaCacheService.prefetch(<String>[url], limit: 1)'));
      expect(clips, contains('MediaCacheService.prefetch(<String>[url], limit: 1)'));
    });
  });

  group('Zameel 072 push and CI regression contracts', () {
    test('Android direct messages stay high-priority data pushes', () {
      final push = _read(
        'supabase/functions/send-push-notifications/index.ts',
      );

      expect(push, contains('priority: "HIGH"'));
      expect(push, contains('sender_id'));
      expect(push, contains('sender_name'));
      expect(push, contains('sender_avatar'));
      expect(push, contains('message_preview'));
      expect(push, contains('.select("id")'));
      expect(push, contains('if (!claimed) continue;'));
      expect(push, contains('stale_processing_recovered'));
      final recovery = _read('supabase/migrations/069_push_queue_processing_recovery.sql');
      expect(recovery, contains('processing_started_at'));
      expect(recovery, contains('push_queue_processing_timestamp'));
    });

    test('test APK cannot silently build without Firebase configuration', () {
      final ci = _read('codemagic.yaml');

      expect(ci, contains('GOOGLE_SERVICES_JSON_BASE64 is required'));
      expect(ci, isNot(contains('building without Firebase push configuration')));
      expect(ci, contains('flutter: 3.47.1'));
      expect(ci, contains('flutter analyze --no-pub'));
      expect(ci, contains('flutter test --no-pub'));
      expect(ci, contains('"project_id"[[:space:]]*:[[:space:]]*"zameel-81ff6"'));
      expect(ci, contains('"package_name"[[:space:]]*:[[:space:]]*"com.zameel.app"'));
    });
  });
  group('Zameel 072 schema-order regression contracts', () {
    test('direct-conversation RPC uses the canonical joined_at membership column', () {
      final migration = _read('supabase/migrations/012_relationship_controls.sql');

      expect(
        migration,
        contains('insert into public.conversation_members(id, conversation_id, user_id, joined_at)'),
      );
      expect(
        migration,
        isNot(contains('insert into public.conversation_members(id, conversation_id, user_id, created_at)')),
      );
    });

    test('story-view write policies tolerate viewer_id and legacy user_id schemas', () {
      final migration = _read('supabase/migrations/061_privacy_search_books_battery_cleanup.sql');

      expect(migration, contains("column_name='viewer_id'"));
      expect(migration, contains("column_name='user_id'"));
      expect(migration, contains('identity_expr'));
      expect(migration, contains('create policy story_views_self_write'));
      expect(migration, contains('create policy story_views_self_update'));
    });
  });


  group('Zameel 074 maintenance contracts', () {
    test('secure media audience classifier executes real production code', () {
      expect(SecureMediaService.isPublicAudience('public'), isTrue);
      expect(SecureMediaService.isPublicAudience('PUBLIC'), isTrue);
      expect(SecureMediaService.isPublicAudience('friends'), isFalse);
      expect(SecureMediaService.isPublicAudience('private'), isFalse);

      final ref = SecureMediaService.privateReference(
        'posts/00000000-0000-0000-0000-000000000001/'
        '00000000-0000-0000-0000-000000000002/photo.jpg',
      );
      expect(SecureMediaService.isPrivateReference(ref), isTrue);
      expect(ref, startsWith('zameel-private://zameel_private_media'));
    });

    test('private storage and cleanup migration is present', () {
      final migration = _read(
        'supabase/migrations/074_private_media_and_push_delivery.sql',
      );
      expect(migration, contains("'zameel_private_media'"));
      expect(migration, contains("update storage.buckets set public = false where id in ('posts', 'graduation_book')"));
      expect(migration, contains('create policy zameel_private_media_read'));
      expect(migration, contains('create policy zameel_private_media_insert'));
      expect(migration, contains('claim_push_device_token'));
      expect(migration, contains('push_notification_deliveries'));
    });

    test('every explicit logout goes through token-safe session service', () {
      final authApp = _read('lib/features/auth_app.dart');
      final home = _read('lib/features/home_feed.dart');
      final settings = _read('lib/screens/profile/profile_settings_screen.dart');
      final session = _read('lib/services/auth_session_service.dart');

      expect(authApp, contains('AuthSessionService.signOut()'));
      expect(home, contains('AuthSessionService.signOut()'));
      expect(settings, contains('AuthSessionService.signOut()'));
      expect(session, contains('unregisterCurrentDevice()'));
      expect(session, contains('client.auth.signOut()'));

      final rawSignOutFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) => !file.path.endsWith('auth_session_service.dart'))
          .where((file) => file.readAsStringSync().contains('.auth.signOut()'))
          .map((file) => file.path)
          .toList();
      expect(rawSignOutFiles, isEmpty);
    });

    test('Android bubbles cover Android 10 and modern shortcut bubbles', () {
      final receiver = _read(
        'android/app/src/main/kotlin/com/zameel/app/ZameelBubbleReceiver.kt',
      );
      final activity = _read(
        'android/app/src/main/kotlin/com/zameel/app/MainActivity.kt',
      );

      expect(receiver, contains('Notification.BubbleMetadata.Builder()'));
      expect(receiver, contains('.setIntent(bubblePendingIntent)'));
      expect(receiver, contains('Notification.BubbleMetadata.Builder(shortcutId)'));
      expect(receiver, contains('shortcutManager.pushDynamicShortcut(shortcut)'));
      expect(receiver, contains('pushDynamicShortcut(shortcut)\n            true'));
      expect(activity, contains('channels.all { it.canBubble() }'));
    });

    test('content deletion removes backing Storage references', () {
      final posts = _read('lib/services/post_publish_service.dart');
      final social = _read('lib/services_social.dart');
      final profile = _read('lib/screens/profile/profile_screen.dart');
      final home = _read('lib/features/home_feed.dart');

      expect(posts, contains('SecureMediaService.removePostMedia'));
      expect(social, contains('SecureMediaService.removeReference'));
      expect(profile, contains('PostPublishService.deletePost'));
      expect(home, contains('PostPublishService.deletePost'));
    });

    test('push retry ledger skips devices already delivered successfully', () {
      final push = _read('supabase/functions/send-push-notifications/index.ts');
      expect(push, contains('push_notification_deliveries'));
      expect(push, contains('previousDelivery?.status === "sent"'));
      expect(push, contains('continue;'));
      expect(push, contains('onConflict: "queue_id,token_id"'));
    });

    test('native story and clip video uploads do not load whole video into RAM', () {
      final stories = _read('lib/screens/stories/stories_screen.dart');
      final clips = _read('lib/screens/social/clip_create_screen.dart');
      final social = _read('lib/services_social.dart');

      expect(stories, contains('kIsWeb ? await video.readAsBytes() : null'));
      expect(clips, contains('kIsWeb ? await file.readAsBytes() : null'));
      expect(social, contains('createStoryFile'));
      expect(social, contains('createClipFile'));
      expect(social, contains('uploadPickedPostMedia'));
    });

    test('foreground special-use declaration matches message-triggered bubble host', () {
      final manifest = _read('android/app/src/main/AndroidManifest.xml');
      expect(
        manifest,
        contains('User-enabled short-lived floating direct-message overlay started only for an incoming Zameel message'),
      );
    });

    test('main Flutter library stays free of direct dart io dependency', () {
      final main = _read('lib/main.dart');
      final home = _read('lib/features/home_feed.dart');
      final drawer = _read('lib/features/drawer_profile.dart');
      expect(main, isNot(contains("import 'dart:io'")));
      // Guard against direct dart:io usage rather than matching method names like isVideoFile(...).
      expect(home, isNot(contains("import 'dart:io'")));
      expect(drawer, isNot(contains('FileImage(')));
      expect(main, contains("platform/local_image_provider.dart"));

      const allowedIoFiles = <String>{
        'lib/platform/local_image_provider_io.dart',
        'lib/platform/local_image_widget_io.dart',
        'lib/platform/video_controller_factory_io.dart',
        'lib/services/media_cache_service_io.dart',
        'lib/services/post_media_storage_uploader_io.dart',
        'lib/widgets/cached_media_image_io.dart',
        'lib/services/social_daily_file_service_io.dart',
      };
      final directIoImports = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) => file.readAsStringSync().contains("import 'dart:io'"))
          .map((file) => file.path.replaceAll('\\', '/'))
          .toSet();
      expect(directIoImports, allowedIoFiles);
    });

    test('control-flow-in-finally is no longer suppressed', () {
      final analysis = _read('analysis_options.yaml');
      expect(analysis, isNot(contains('control_flow_in_finally: ignore')));
    });

    test('verified registration cannot be skipped and keeps legal data private', () {
      final migration = _read('supabase/migrations/076_registration_radio_college_challenge.sql');
      final gate = _read('lib/features/auth_app.dart');
      final verification = _read('lib/screens/auth/contact_verification_screen.dart');
      expect(migration, contains('zameel_registration_profiles'));
      expect(migration, contains('registration_owner_read'));
      expect(migration, contains('registration_one_verified_channel'));
      expect(gate, contains("profile['onboarding_complete'] != true"));
      expect(verification, contains("'first_name'"));
      expect(verification, contains("'father_name'"));
      expect(verification, contains("'family_name'"));
      expect(verification, contains("'verification_method'"));
    });

    test('radio and beautiful college remain independent destinations', () {
      final home = _read('lib/features/home_feed.dart');
      final radio = _read('lib/screens/social/zameel_radio_screen.dart');
      final challenge = _read('lib/screens/social/beautiful_college_screen.dart');
      final migration = _read('supabase/migrations/076_registration_radio_college_challenge.sql');
      expect(home, contains("case 'radio':"));
      expect(home, contains("case 'beautiful_college':"));
      expect(radio, contains('duration_seconds'));
      expect(radio, contains('zameel_mute_radio_author'));
      expect(migration, contains("now()+interval '7 days'"));
      expect(challenge, contains('zameel_toggle_college_like'));
      expect(challenge, contains('download'));
      expect(migration, contains('zameel_radio_two_reports'));
      expect(migration, contains('zameel_college_two_reports'));
    });
  });

}
