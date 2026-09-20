import 'package:supabase_flutter/supabase_flutter.dart';

import 'push_notification_service.dart';

/// Single exit path for a signed-in session.
///
/// Removing the current device token before Supabase sign-out prevents a token
/// from remaining attached to the previous account when another user signs in
/// on the same phone.
class AuthSessionService {
  AuthSessionService._();

  static Future<void> signOut() async {
    try {
      await PushNotificationService.instance.unregisterCurrentDevice();
    } finally {
      await Supabase.instance.client.auth.signOut();
    }
  }
}
