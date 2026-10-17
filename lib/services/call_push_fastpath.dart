import 'package:supabase_flutter/supabase_flutter.dart';

/// Asks the push worker to ring the other phone right now.
///
/// The database already queues the same push, but that route can take many
/// seconds. This direct request (made by the caller, verified by the worker
/// with the caller's own login) usually arrives in well under a second. If it
/// fails nothing is lost: the normal route still delivers the call.
class CallPushFastPath {
  CallPushFastPath._();

  static Future<void> ring(String roomId) async {
    try {
      await Supabase.instance.client.functions.invoke(
        'send-push-notifications',
        body: <String, dynamic>{'call_room': roomId},
      );
    } catch (_) {
      // Best effort only.
    }
  }
}
