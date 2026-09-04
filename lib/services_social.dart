import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    final contentType = switch (safeExt) {
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'webm' => 'video/webm',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      _ => null,
    };
    await db.storage.from(type == 'clip' ? 'clips' : 'posts').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        contentType: contentType,
        upsert: false,
      ),
    );
    return db.storage.from(type == 'clip' ? 'clips' : 'posts').getPublicUrl(path);
  }

  static Future<void> createStory({String? mediaUrl, required String mediaType, String caption = '', required String audience}) async {
    final id = uid;
    if (id == null) return;
    await db.from('social_stories').insert({
      'user_id': id,
      'media_url': mediaUrl,
      'media_type': mediaType,
      'caption': caption,
      'audience': audience,
    });
  }

  static Future<void> upsertNote(String text, {required String audience}) async {
    final id = uid;
    if (id == null) return;
    await db.from('social_notes').upsert({
      'user_id': id,
      'text': text,
      'audience': audience,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'expires_at': DateTime.now().toUtc().add(const Duration(hours: 24)).toIso8601String(),
    });
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
    final row = await db.from('clips').insert({
      'user_id': id,
      'video_url': url,
      'caption': caption,
      'duration_seconds': durationSeconds.clamp(1, 120),
      'audience': audience,
    }).select('id').single();
    return row['id'] as String?;
  }

  static Future<List<Map<String, dynamic>>> loadStories() async {
    if (!signedIn) return [];
    final rows = await db.from('social_stories').select().gt('expires_at', DateTime.now().toUtc().toIso8601String()).order('created_at', ascending: false).limit(50);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<List<Map<String, dynamic>>> loadClips() async {
    if (!signedIn) return [];
    final rows = await db.from('clips').select().order('created_at', ascending: false).limit(50);
    return List<Map<String, dynamic>>.from(rows);
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

  static Future<void> addClipComment(String clipId, String text) async {
    final id = uid;
    if (id == null || text.trim().isEmpty) return;
    await db.from('clip_comments').insert({'clip_id': clipId, 'user_id': id, 'text': text.trim()});
  }

  static Future<List<Map<String, dynamic>>> loadComments(String clipId) async {
    if (!signedIn) return [];
    final rows = await db.from('clip_comments').select().eq('clip_id', clipId).order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<void> setCloseFriend(String friendId, bool value) async {
    final id = uid;
    if (id == null) return;
    if (value) {
      await db.from('close_friends').upsert({'user_id': id, 'friend_id': friendId});
    } else {
      await db.from('close_friends').delete().eq('user_id', id).eq('friend_id', friendId);
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
