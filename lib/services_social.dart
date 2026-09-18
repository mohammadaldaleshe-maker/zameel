import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/media_cache_service.dart';

class ZameelSocialService {
  static final SupabaseClient db = Supabase.instance.client;
  static String? get uid => db.auth.currentUser?.id;
  static bool get signedIn => uid != null;

  static Future<String?> uploadMedia(File file, {required String type}) async {
    final bytes = await file.readAsBytes();
    return uploadMediaBytes(bytes, filename: file.path, type: type);
  }

  static Future<String?> uploadMediaBytes(Uint8List bytes, {required String filename, required String type}) async {
    final id = uid;
    if (id == null) return null;
    final ext = filename.split('.').last.toLowerCase();
    final safeExt = ext.isEmpty || ext.length > 8 ? 'bin' : ext;
    final path = '$id/social/${type}_${DateTime.now().millisecondsSinceEpoch}.$safeExt';
    await db.storage.from('posts').uploadBinary(path, bytes);
    final url = db.storage.from('posts').getPublicUrl(path);
    await MediaCacheService.storeBytes(url, bytes);
    return url;
  }

  static Future<String?> createStory({String? mediaUrl, required String mediaType, String caption = '', required String audience}) async {
    final id = uid;
    if (id == null) return null;
    if (mediaUrl != null && mediaUrl.trim().isNotEmpty) {
      final ready = await MediaCacheService.waitUntilRemoteReady(mediaUrl);
      if (!ready) {
        throw StateError('story_media_not_ready');
      }
    }
    final row = await db.from('social_stories').insert({
      'user_id': id,
      'media_url': mediaUrl,
      'media_type': mediaType,
      'caption': caption,
      'audience': audience,
    }).select('id').single();
    return row['id']?.toString();
  }


  static Future<void> recordStoryView(String storyId) async {
    final id = uid;
    if (id == null || storyId.trim().isEmpty) return;
    // The RPC detects whether the deployed story_views table uses viewer_id
    // or legacy user_id. Keeping that compatibility in PostgreSQL prevents a
    // client build from silently losing views because of schema drift.
    await db.rpc('record_story_view', params: {'target_story_id': storyId});
  }

  static Future<bool> toggleStoryReaction(String storyId) async {
    final id = uid;
    if (id == null || storyId.trim().isEmpty) return false;
    final existing = await db.from('story_reactions').select('story_id').eq('story_id', storyId).eq('user_id', id).maybeSingle();
    if (existing != null) {
      await db.from('story_reactions').delete().eq('story_id', storyId).eq('user_id', id);
      return false;
    }
    await db.from('story_reactions').upsert({'story_id': storyId, 'user_id': id, 'reaction': '❤️'});
    return true;
  }

  static Future<List<Map<String, dynamic>>> loadStoryViewers(String storyId) async {
    if (!signedIn || storyId.trim().isEmpty) return [];
    final rows = await db.rpc(
      'get_story_viewers',
      params: {'target_story_id': storyId},
    );
    if (rows is! List) return [];
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  static Future<List<Map<String, dynamic>>> loadStoryReactions(String storyId) async {
    if (!signedIn || storyId.trim().isEmpty) return [];
    final rows = await db.rpc(
      'get_story_reactions',
      params: {'target_story_id': storyId},
    );
    if (rows is! List) return [];
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  static Future<Map<String, int>> loadStoryEngagementCounts(String storyId) async {
    if (!signedIn || storyId.trim().isEmpty) {
      return const {'views': 0, 'reactions': 0};
    }
    final rows = await db.rpc(
      'get_story_engagement_counts',
      params: {'target_story_id': storyId},
    );
    if (rows is! List || rows.isEmpty || rows.first is! Map) {
      return const {'views': 0, 'reactions': 0};
    }
    final row = Map<String, dynamic>.from(rows.first as Map);
    return {
      'views': (row['views_count'] as num?)?.toInt() ?? 0,
      'reactions': (row['reactions_count'] as num?)?.toInt() ?? 0,
    };
  }

  static Future<bool> isStoryReacted(String storyId) async {
    final id = uid;
    if (id == null || storyId.trim().isEmpty) return false;
    final row = await db.from('story_reactions').select('story_id').eq('story_id', storyId).eq('user_id', id).maybeSingle();
    return row != null;
  }

  static Future<void> deleteStory(String storyId) async {
    final id = uid;
    if (id == null || storyId.trim().isEmpty) return;
    await db.from('social_stories').delete().eq('id', storyId).eq('user_id', id);
  }

  static Future<String?> createClip({required File file, String caption = '', int durationSeconds = 1, required String audience}) async {
    final bytes = await file.readAsBytes();
    return createClipBytes(
      bytes: bytes,
      filename: file.path,
      caption: caption,
      durationSeconds: durationSeconds,
      audience: audience,
    );
  }

  static Future<String?> createClipBytes({required Uint8List bytes, required String filename, String caption = '', int durationSeconds = 1, required String audience}) async {
    final id = uid;
    if (id == null) return null;
    final url = await uploadMediaBytes(bytes, filename: filename, type: 'clip');
    if (url == null) return null;
    final ready = await MediaCacheService.waitUntilRemoteReady(url);
    if (!ready) {
      throw StateError('clip_media_not_ready');
    }
    final row = await db.from('clips').insert({
      'user_id': id,
      'video_url': url,
      'caption': caption,
      'duration_seconds': durationSeconds.clamp(1, 45),
      'audience': audience,
    }).select('id').single();
    return row['id'] as String?;
  }

  static Future<List<Map<String, dynamic>>> loadStories({bool friendsOnly = false}) async {
    if (!signedIn) return [];
    final id = uid!;
    final raw = await db
        .from('social_stories')
        .select()
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('created_at', ascending: false)
        .limit(40);
    var stories = List<Map<String, dynamic>>.from(raw);

    final userIds = <String>{id, ...stories.map((story) => story['user_id']?.toString()).whereType<String>()}.toList();
    final users = userIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await db
                .from('users')
                .select('id,name,profile_image,university,college,department')
                .inFilter('id', userIds),
          );
    final byId = <String, Map<String, dynamic>>{
      for (final user in users) user['id'].toString(): user,
    };
    final me = byId[id] ?? const <String, dynamic>{};

    final requests = await db
        .from('friend_requests')
        .select('sender_id,receiver_id,status')
        .eq('status', 'accepted')
        .or('sender_id.eq.$id,receiver_id.eq.$id');
    final friendIds = <String>{id};
    for (final request in requests) {
      final sender = request['sender_id']?.toString();
      final receiver = request['receiver_id']?.toString();
      if (sender != null && sender != id) friendIds.add(sender);
      if (receiver != null && receiver != id) friendIds.add(receiver);
    }

    final closeFriendRows = await db
        .from('close_friends')
        .select('owner_id')
        .eq('friend_id', id);
    final closeFriendOwners = closeFriendRows
        .map((row) => row['owner_id']?.toString())
        .whereType<String>()
        .toSet();

    String normalized(dynamic value) => value?.toString().trim().toLowerCase() ?? '';
    bool sameCollege(Map<String, dynamic> owner) {
      final myUniversity = normalized(me['university']);
      final myCollege = normalized(me['college']);
      return myUniversity.isNotEmpty &&
          myCollege.isNotEmpty &&
          normalized(owner['university']) == myUniversity &&
          normalized(owner['college']) == myCollege;
    }

    bool sameDepartment(Map<String, dynamic> owner) {
      final myDepartment = normalized(me['department']);
      return sameCollege(owner) &&
          myDepartment.isNotEmpty &&
          normalized(owner['department']) == myDepartment;
    }

    stories = stories.where((story) {
      final ownerId = story['user_id']?.toString() ?? '';
      final owner = byId[ownerId] ?? const <String, dynamic>{};
      story['users'] = owner;
      if (ownerId == id) return true;

      final audience = story['audience']?.toString() ?? 'public';
      bool visible;
      if (audience == 'public') {
        visible = true;
      } else if (audience == 'friends') {
        visible = friendIds.contains(ownerId);
      } else if (audience == 'close_friends') {
        visible = closeFriendOwners.contains(ownerId);
      } else if (audience == 'college' || audience == 'faculty') {
        visible = sameCollege(owner);
      } else if (audience == 'department' || audience == 'group') {
        visible = sameDepartment(owner);
      } else {
        visible = false;
      }
      if (!visible) return false;
      return !friendsOnly || friendIds.contains(ownerId);
    }).toList();

    return stories;
  }

  static Future<List<Map<String, dynamic>>> loadClips() async {
    if (!signedIn) return [];
    final currentUserId = uid!;
    final rows = await db
        .from('clips')
        .select('*, users(name,profile_image)')
        .order('created_at', ascending: false)
        .limit(20);
    final clips = List<Map<String, dynamic>>.from(rows);
    final clipIds = clips
        .map((clip) => clip['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();
    if (clipIds.isEmpty) return clips;

    final likedRows = await db
        .from('clip_likes')
        .select('clip_id')
        .eq('user_id', currentUserId)
        .inFilter('clip_id', clipIds);
    final likedIds = List<Map<String, dynamic>>.from(likedRows)
        .map((row) => row['clip_id']?.toString())
        .whereType<String>()
        .toSet();
    for (final clip in clips) {
      clip['liked'] = likedIds.contains(clip['id']?.toString());
    }
    return clips;
  }

  static Future<void> updateClip(String clipId, {String? audience, bool? hidden}) async {
    final id = uid;
    if (id == null) return;
    final values = <String, dynamic>{};
    if (audience != null) values['audience'] = audience;
    if (hidden != null) values['is_hidden'] = hidden;
    if (values.isEmpty) return;
    await db.from('clips').update(values).eq('id', clipId).eq('user_id', id);
  }

  static Future<void> deleteClip(String clipId) async {
    final id = uid;
    if (id == null) return;
    try {
      await db.rpc('delete_clip_authorized', params: {
        'target_clip_id': clipId,
      });
    } on PostgrestException catch (error) {
      if (!error.message.contains('delete_clip_authorized') &&
          error.code != 'PGRST202') {
        rethrow;
      }
      await db.from('clips').delete().eq('id', clipId).eq('user_id', id);
    }
  }

  static Future<void> toggleClipLike(String clipId, bool liked) async {
    final id = uid;
    if (id == null) return;
    if (liked) {
      await db.from('clip_likes').delete().eq('clip_id', clipId).eq('user_id', id);
    } else {
      await db.from('clip_likes').upsert({'clip_id': clipId, 'user_id': id});
    }
  }

  static Future<bool> isClipLiked(String clipId) async {
    final id = uid;
    if (id == null) return false;
    final row = await db.from('clip_likes').select('clip_id').eq('clip_id', clipId).eq('user_id', id).maybeSingle();
    return row != null;
  }

  static Future<void> addClipComment(
    String clipId,
    String text, {
    String? parentCommentId,
  }) async {
    final id = uid;
    if (id == null || text.trim().isEmpty) return;
    await db.from('clip_comments').insert({
      'clip_id': clipId,
      'user_id': id,
      'text': text.trim(),
      'parent_comment_id': parentCommentId,
    });
  }

  static Future<Map<String, Map<String, dynamic>>> loadUserProfiles(
    Iterable<String> userIds,
  ) async {
    final ids = userIds.where((id) => id.trim().isNotEmpty).toSet().toList();
    if (ids.isEmpty) return <String, Map<String, dynamic>>{};
    final rows = await db
        .from('users')
        .select('id,name,username,profile_image,department')
        .inFilter('id', ids);
    final users = List<Map<String, dynamic>>.from(rows);
    return <String, Map<String, dynamic>>{
      for (final user in users)
        if (user['id'] != null) user['id'].toString(): user,
    };
  }

  static Future<List<Map<String, dynamic>>> loadComments(String clipId) async {
    if (!signedIn) return [];
    final rows = await db
        .from('clip_comments')
        .select(
          'id,clip_id,user_id,text,created_at,updated_at,parent_comment_id,likes_count',
        )
        .eq('clip_id', clipId)
        .order('created_at', ascending: true);
    final comments = List<Map<String, dynamic>>.from(rows);
    final profiles = await loadUserProfiles(
      comments
          .map((comment) => comment['user_id']?.toString())
          .whereType<String>(),
    );
    for (final comment in comments) {
      comment['users'] = profiles[comment['user_id']?.toString()] ??
          const <String, dynamic>{};
    }
    return comments;
  }

  static Future<Set<String>> loadMyClipCommentLikes(
    List<String> commentIds,
  ) async {
    final id = uid;
    if (id == null || commentIds.isEmpty) return <String>{};
    final rows = await db
        .from('clip_comment_likes')
        .select('comment_id')
        .eq('user_id', id)
        .inFilter('comment_id', commentIds);
    return List<Map<String, dynamic>>.from(rows)
        .map((row) => row['comment_id']?.toString())
        .whereType<String>()
        .toSet();
  }

  static Future<void> toggleClipCommentLike(
    String commentId,
    bool liked,
  ) async {
    final id = uid;
    if (id == null || commentId.trim().isEmpty) return;
    if (liked) {
      await db
          .from('clip_comment_likes')
          .delete()
          .eq('comment_id', commentId)
          .eq('user_id', id);
    } else {
      await db.from('clip_comment_likes').upsert({
        'comment_id': commentId,
        'user_id': id,
      });
    }
  }

  static Future<void> updateClipComment(String commentId, String text) async {
    final id = uid;
    if (id == null || text.trim().isEmpty) return;
    await db
        .from('clip_comments')
        .update({
          'text': text.trim(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', commentId)
        .eq('user_id', id);
  }

  static Future<void> deleteClipComment(String commentId) async {
    final id = uid;
    if (id == null) return;
    await db
        .from('clip_comments')
        .delete()
        .eq('id', commentId)
        .eq('user_id', id);
  }

  static Future<Map<String, dynamic>?> loadClipEngagement(String clipId) async {
    if (!signedIn || clipId.trim().isEmpty) return null;
    final row = await db
        .from('clips')
        .select('likes_count,comments_count')
        .eq('id', clipId)
        .maybeSingle();
    if (row == null) return null;
    final result = Map<String, dynamic>.from(row);
    result['liked'] = await isClipLiked(clipId);
    return result;
  }

  static Future<void> shareClip(String clipId) async {
    final id = uid;
    if (id == null) return;
    await db.from('shared_clips').upsert({'clip_id': clipId, 'shared_by': id});
  }

  static Future<void> setCloseFriend(String friendId, bool value) async {
    final id = uid;
    if (id == null) return;
    if (value) {
      await db.from('close_friends').upsert({'owner_id': id, 'friend_id': friendId});
    } else {
      await db.from('close_friends').delete().eq('owner_id', id).eq('friend_id', friendId);
    }
  }

  static Future<void> toggleFollow(String targetId, bool following) async {
    final id = uid;
    if (id == null || id == targetId) return;
    if (following) {
      await db.from('follows').delete().eq('follower_id', id).eq('following_id', targetId);
    } else {
      await db.from('follows').upsert({'follower_id': id, 'following_id': targetId});
    }
  }
}
