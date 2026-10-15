import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> hydratePostLikes161(
    SupabaseClient db, String userId, List<Map<String, dynamic>> posts) async {
  if (posts.isEmpty) return;
  final rows = await db
      .from('likes')
      .select('post_id')
      .eq('user_id', userId)
      .inFilter('post_id', posts.map((p) => '${p['id']}').toList());
  if (db.auth.currentUser?.id != userId) return;
  final ids = rows.map((row) => '${row['post_id']}').toSet();
  for (final post in posts) {
    post['liked'] = ids.contains('${post['id']}');
  }
}

class PostLikeResult161 {
  const PostLikeResult161(this.changed, this.count);
  final bool changed;
  final int? count;

  int displayCount(int previous, {required bool liked}) =>
      count ??
      (previous + (changed ? (liked ? 1 : -1) : 0)).clamp(0, 2147483647);
}

/// A repeated request sets the same state without adding another like.
Future<PostLikeResult161> setPostLike161(SupabaseClient db,
    {required String userId,
    required String postId,
    required bool liked}) async {
  if (db.auth.currentUser?.id != userId) {
    throw StateError('The active account changed.');
  }
  final List<dynamic> affected;
  if (liked) {
    affected = await db.from('likes').upsert(
      {'user_id': userId, 'post_id': postId},
      onConflict: 'user_id,post_id',
      ignoreDuplicates: true,
    ).select('user_id');
  } else {
    affected = await db
        .from('likes')
        .delete()
        .eq('user_id', userId)
        .eq('post_id', postId)
        .select('user_id');
  }
  int? count;
  try {
    final post = await db
        .from('posts')
        .select('likes_count')
        .eq('id', postId)
        .maybeSingle();
    final value = post?['likes_count'];
    if (value is num) count = value.toInt();
  } catch (_) {
    // A failed refresh must not roll back an already committed like locally.
  }
  return PostLikeResult161(affected.isNotEmpty, count);
}
