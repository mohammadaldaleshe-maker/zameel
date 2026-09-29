import 'package:supabase_flutter/supabase_flutter.dart';

import 'push_notification_service.dart';
import 'media_cache_service.dart';
import 'feed_snapshot_service.dart';

/// Single exit path for a signed-in session.
///
/// Removing the current device token before Supabase sign-out prevents a token
/// from remaining attached to the previous account when another user signs in
/// on the same phone.
class AuthSessionService {
  AuthSessionService._();

  static Future<void> signOut() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    try {
      await PushNotificationService.instance.unregisterCurrentDevice();
    } finally {
      if (userId != null) {
        try {
          await FeedSnapshotService.clear(userId);
          await MediaCacheService.clearPrivateMediaForUser(userId);
        } catch (_) {}
      }
      await Supabase.instance.client.auth.signOut();
    }
  }
}
