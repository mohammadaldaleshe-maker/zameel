import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'services/media_cache_service.dart';
import 'services/post_media_storage_uploader.dart';
import 'services/secure_media_service.dart';

class ZameelSocialService {
  static final SupabaseClient db = Supabase.instance.client;
  static String? get uid => db.auth.currentUser?.id;
  static bool get signedIn => uid != null;

  static const int _maxImageBytes = 12 * 1024 * 1024;
  static const int _maxVideoBytes = 80 * 1024 * 1024;

  /// Legacy byte upload remains for small/public compatibility paths. New story
  /// and clip publishing uses XFile streaming below so native videos are never
  /// loaded wholly into RAM.
  static Future<String?> uploadMediaBytes(Uint8List bytes, {required String filename, required String type}) async {
    final id = uid;
    if (id == null) return null;
    final ext = _safeExtension(filename);
    final path = '$id/social/${type}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await db.storage.from('posts').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: _contentType(ext, type.contains('video') || type == 'clip'), upsert: false),
    );
    final url = db.storage.from('posts').getPublicUrl(path);
    await MediaCacheService.storeBytes(url, bytes);
    return url;
  }

  static Future<String?> createStory({String? mediaUrl, required String mediaType, String caption = '', required String audience}) async {
    final id = uid;
    if (id == null) return null;
    if (mediaUrl != null && mediaUrl.trim().isNotEmpty) {
      final ready = await MediaCacheService.waitUntilRemoteReady(await SecureMediaService.resolve(mediaUrl));
      if (!ready) throw StateError('story_media_not_ready');
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

  static Future<String?> createStoryFile({
    required XFile file,
    required String mediaType,
    String caption = '',
    required String audience,
  }) async {
    final id = uid;
    if (id == null) return null;
    final row = await db.from('social_stories').insert({
      'user_id': id,
      'media_url': null,
      'media_type': mediaType,
      'caption': caption,
      'audience': audience,
    }).select('id').single();
    final storyId = row['id']?.toString() ?? '';
    if (storyId.isEmpty) throw StateError('story_id_missing');

    final ext = _safeExtension(file.name);
    final video = mediaType == 'video';
    final isPublic = SecureMediaService.isPublicAudience(audience);
    final bucket = isPublic ? 'posts' : SecureMediaService.privateBucket;
    final path = isPublic
        ? '$id/social/story_${DateTime.now().microsecondsSinceEpoch}.$ext'
        : 'stories/$storyId/$id/${DateTime.now().microsecondsSinceEpoch}.$ext';
    try {
      await uploadPickedPostMedia(
        client: db,
        bucket: bucket,
        storagePath: path,
        source: file,
        maxBytes: video ? _maxVideoBytes : _maxImageBytes,
        tooLargeError: video ? 'video_too_large_80mb' : 'image_too_large_12mb',
        contentType: _contentType(ext, video),
      );
      final storedRef = isPublic
          ? db.storage.from(bucket).getPublicUrl(path)
          : SecureMediaService.privateReference(path);
      await db.from('social_stories').update({'media_url': storedRef}).eq('id', storyId).eq('user_id', id);
      final readyUrl = await SecureMediaService.resolve(storedRef);
      final ready = await MediaCacheService.waitUntilRemoteReady(readyUrl);
      if (!ready) throw StateError('story_media_not_ready');
      return storyId;
    } catch (_) {
      try { await db.storage.from(bucket).remove(<String>[path]); } catch (_) {}
      try { await db.from('social_stories').delete().eq('id', storyId).eq('user_id', id); } catch (_) {}
      rethrow;
    }
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
    final row = await db.from('social_stories').select('media_url').eq('id', storyId).eq('user_id', id).maybeSingle();
    await db.from('social_stories').delete().eq('id', storyId).eq('user_id', id);
    await SecureMediaService.removeReference(row?['media_url']?.toString());
  }

  static Future<String?> createClipFile({
    required XFile file,
    String caption = '',
    int durationSeconds = 1,
    required String audience,
  }) async {
    final id = uid;
    if (id == null) return null;
    final row = await db.from('clips').insert({
      'user_id': id,
      'video_url': 'uploading://pending',
      'caption': caption,
      'duration_seconds': durationSeconds.clamp(1, 45),
      'audience': audience,
    }).select('id').single();
    final clipId = row['id']?.toString() ?? '';
    if (clipId.isEmpty) throw StateError('clip_id_missing');
    final ext = _safeExtension(file.name);
    final isPublic = SecureMediaService.isPublicAudience(audience);
    final bucket = isPublic ? 'posts' : SecureMediaService.privateBucket;
    final path = isPublic
        ? '$id/social/clip_${DateTime.now().microsecondsSinceEpoch}.$ext'
        : 'clips/$clipId/$id/${DateTime.now().microsecondsSinceEpoch}.$ext';
    try {
      await uploadPickedPostMedia(
        client: db,
        bucket: bucket,
        storagePath: path,
        source: file,
        maxBytes: _maxVideoBytes,
        tooLargeError: 'video_too_large_80mb',
        contentType: _contentType(ext, true),
      );
      final storedRef = isPublic
          ? db.storage.from(bucket).getPublicUrl(path)
          : SecureMediaService.privateReference(path);
      await db.from('clips').update({'video_url': storedRef}).eq('id', clipId).eq('user_id', id);
      final ready = await MediaCacheService.waitUntilRemoteReady(await SecureMediaService.resolve(storedRef));
      if (!ready) throw StateError('clip_media_not_ready');
      return clipId;
    } catch (_) {
      try { await db.storage.from(bucket).remove(<String>[path]); } catch (_) {}
      try { await db.from('clips').delete().eq('id', clipId).eq('user_id', id); } catch (_) {}
      rethrow;
    }
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

    await Future.wait(stories.map(SecureMediaService.resolveStory));
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
    await Future.wait(clips.map(SecureMediaService.resolveClip));
    return clips;
  }

  static Future<void> updateClip(String clipId, {String? audience, bool? hidden}) async {
    final id = uid;
    if (id == null) return;
    final values = <String, dynamic>{};
    String? oldRefToDelete;
    if (audience != null) {
      final current = await db.from('clips').select('audience,video_url').eq('id', clipId).eq('user_id', id).single();
      final oldAudience = current['audience']?.toString() ?? 'public';
      final oldUrl = current['video_url']?.toString() ?? '';
      if (SecureMediaService.isPublicAudience(oldAudience) &&
          !SecureMediaService.isPublicAudience(audience) &&
          oldUrl.isNotEmpty && !SecureMediaService.isPrivateReference(oldUrl)) {
        final path = _publicPostsPath(oldUrl);
        final bytes = await db.storage.from('posts').download(path);
        final ext = _safeExtension(path);
        final privatePath = 'clips/$clipId/$id/${DateTime.now().microsecondsSinceEpoch}.$ext';
        await db.storage.from(SecureMediaService.privateBucket).uploadBinary(
          privatePath,
          bytes,
          fileOptions: FileOptions(contentType: _contentType(ext, true), upsert: false),
        );
        values['video_url'] = SecureMediaService.privateReference(privatePath);
        oldRefToDelete = oldUrl;
      }
      values['audience'] = audience;
    }
    if (hidden != null) values['is_hidden'] = hidden;
    if (values.isEmpty) return;
    await db.from('clips').update(values).eq('id', clipId).eq('user_id', id);
    if (oldRefToDelete != null) await SecureMediaService.removeReference(oldRefToDelete);
  }

  static Future<void> deleteClip(String clipId) async {
    final id = uid;
    if (id == null) return;
    final row = await db.from('clips').select('video_url').eq('id', clipId).maybeSingle();
    try {
      await db.rpc('delete_clip_authorized', params: {'target_clip_id': clipId});
    } on PostgrestException catch (error) {
      if (!error.message.contains('delete_clip_authorized') && error.code != 'PGRST202') rethrow;
      await db.from('clips').delete().eq('id', clipId).eq('user_id', id);
    }
    await SecureMediaService.removeReference(row?['video_url']?.toString());
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

  static String _safeExtension(String filename) {
    final clean = filename.split('?').first;
    final dot = clean.lastIndexOf('.');
    if (dot < 0 || dot == clean.length - 1) return 'bin';
    final ext = clean.substring(dot + 1).toLowerCase();
    return RegExp(r'^[a-z0-9]{1,8}$').hasMatch(ext) ? ext : 'bin';
  }

  static String _contentType(String ext, bool video) {
    if (video) {
      if (ext == 'mov') return 'video/quicktime';
      if (ext == 'webm') return 'video/webm';
      if (ext == 'm4v') return 'video/x-m4v';
      return 'video/mp4';
    }
    if (ext == 'png') return 'image/png';
    if (ext == 'webp') return 'image/webp';
    if (ext == 'gif') return 'image/gif';
    return 'image/jpeg';
  }

  static String _publicPostsPath(String url) {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments;
    final idx = segments.indexOf('public');
    if (idx < 0 || idx + 2 >= segments.length || segments[idx + 1] != 'posts') {
      throw StateError('unsupported_public_media_url');
    }
    return Uri.decodeFull(segments.sublist(idx + 2).join('/'));
  }

}
