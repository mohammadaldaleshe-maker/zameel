import 'package:supabase_flutter/supabase_flutter.dart';
import '../services_social.dart';

/// Resolve visible profiles independently of PostgREST relationship inference.
/// Both queries retain their existing RLS and use a bounded network timeout.
Future<List<Map<String, dynamic>>> loadPostLikers163(String postId) async {
  final db = Supabase.instance.client;
  final actor = db.auth.currentUser?.id;
  final likes = await db
      .from('likes')
      .select('user_id,created_at')
      .eq('post_id', postId)
      .order('created_at', ascending: false)
      .timeout(const Duration(seconds: 12));
  final profiles = await ZameelSocialService.loadUserProfiles(
          likes.map((row) => '${row['user_id']}'))
      .timeout(const Duration(seconds: 12));
  if (db.auth.currentUser?.id != actor) throw StateError('account_changed');
  return [
    for (final row in likes)
      {
        ...row,
        'users': profiles['${row['user_id']}'] ?? const <String, dynamic>{}
      }
  ];
}
