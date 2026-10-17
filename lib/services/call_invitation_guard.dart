import 'package:supabase_flutter/supabase_flutter.dart';

/// A notification is only an invitation hint; the session is authoritative.
class CallInvitationGuard {
  static const maxRingingAge = Duration(seconds: 45);

  static bool isCurrent(
      Map<String, dynamic>? row, String? currentUserId, DateTime now) {
    if (row == null ||
        currentUserId == null ||
        row['status'] != 'ringing' ||
        row['callee_id']?.toString() != currentUserId) return false;
    final created = DateTime.tryParse(row['created_at']?.toString() ?? '');
    if (created == null) return false;
    final age = now.toUtc().difference(created.toUtc());
    // The session row is authoritative. A phone clock that is up to 30 seconds
    // behind the server must not hide a call that is genuinely ringing.
    return age >= const Duration(seconds: -30) && age < maxRingingAge;
  }

  static Future<bool> isRinging(String roomId) async {
    if (roomId.isEmpty) return false;
    try {
      final client = Supabase.instance.client;
      final row = await client
          .from('direct_call_sessions')
          .select('status,callee_id,created_at')
          .eq('room_id', roomId)
          .maybeSingle();
      return isCurrent(row, client.auth.currentUser?.id, DateTime.now());
    } catch (_) {
      return false;
    }
  }
}
