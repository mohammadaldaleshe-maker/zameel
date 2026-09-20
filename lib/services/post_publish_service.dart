import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'post_media_storage_uploader.dart';
import 'secure_media_service.dart';

class PickedPostMedia {
  final XFile source;
  final int byteSize;

  const PickedPostMedia({required this.source, required this.byteSize});

  String get name => source.name;
  String get path => source.path;
  int get lengthSync => byteSize;
  Future<Uint8List> readAsBytes() => source.readAsBytes();
}

/// Publisher for normal feed posts containing mixed media.
///
/// Public posts preserve the legacy public `posts` bucket. Non-public posts use
/// a private bucket and store opaque references that are resolved to signed URLs
/// only for users who pass the existing post RLS rules.
class PostPublishService {
  static const int maxMediaItems = 10;
  static const int maxImageBytes = 12 * 1024 * 1024;
  static const int maxVideoBytes = 80 * 1024 * 1024;
  static const int maxPostMediaBytes = 150 * 1024 * 1024;

  static const List<String> allowedExtensions = <String>[
    'jpg', 'jpeg', 'png', 'webp', 'gif', 'heic', 'heif',
    'mp4', 'mov', 'm4v', 'webm',
  ];

  static const Set<String> _videoExtensions = <String>{'mp4', 'mov', 'm4v', 'webm'};

  static bool isVideoFile(PickedPostMedia file) =>
      _videoExtensions.contains(_extension(file.name));

  static bool isSupportedFile(PickedPostMedia file) =>
      allowedExtensions.contains(_extension(file.name));

  static Future<List<PickedPostMedia>> pickMultipleImages({
    int limit = maxMediaItems,
  }) async {
    if (limit <= 0) return const <PickedPostMedia>[];
    final picked = await ImagePicker().pickMultiImage(imageQuality: 90, limit: limit);
    return _wrapXFiles(picked, limit: limit, onlyVideos: false);
  }

  static Future<List<PickedPostMedia>> pickMultipleVideos({
    int limit = maxMediaItems,
  }) async {
    if (limit <= 0) return const <PickedPostMedia>[];
    final picked = await ImagePicker().pickMultiVideo(limit: limit);
    return _wrapXFiles(picked, limit: limit, onlyVideos: true);
  }

  static Future<List<PickedPostMedia>> pickMultipleMedia({
    int limit = maxMediaItems,
  }) async {
    if (limit <= 0) return const <PickedPostMedia>[];
    final picked = await ImagePicker().pickMultipleMedia(imageQuality: 90, limit: limit);
    return _wrapXFiles(picked, limit: limit);
  }

  static Future<List<PickedPostMedia>> _wrapXFiles(
    Iterable<XFile> picked, {
    required int limit,
    bool? onlyVideos,
  }) async {
    final selected = <PickedPostMedia>[];
    for (final source in picked.take(limit)) {
      final item = PickedPostMedia(source: source, byteSize: await source.length());
      if (!isSupportedFile(item)) continue;
      if (onlyVideos != null && isVideoFile(item) != onlyVideos) continue;
      selected.add(item);
    }
    return selected;
  }

  static Future<Map<String, dynamic>> publishPost({
    required String text,
    required String audience,
    List<PickedPostMedia> media = const <PickedPostMedia>[],
  }) async {
    final db = Supabase.instance.client;
    final user = db.auth.currentUser;
    if (user == null) throw StateError('not_signed_in');

    final cleanText = text.trim();
    final selected = media.where(isSupportedFile).take(maxMediaItems).toList();
    if (cleanText.isEmpty && selected.isEmpty) throw ArgumentError('empty_post');
    _validateSelection(selected);

    // Create the RLS-protected entity before private uploads so Storage policy
    // can authorize the owner and later viewers against this exact post id.
    final draft = Map<String, dynamic>.from(
      await db.from('posts').insert(<String, dynamic>{
        'user_id': user.id,
        'type': selected.isEmpty ? 'text' : (isVideoFile(selected.first) ? 'video' : 'image'),
        'text_ar': cleanText,
        'text_en': cleanText,
        'image_url': null,
        'video_url': null,
        'media_items': const <dynamic>[],
        'likes_count': 0,
        'comments_count': 0,
        'audience': audience,
      }).select().single(),
    );
    final postId = draft['id']?.toString() ?? '';
    if (postId.isEmpty) throw StateError('post_id_missing');

    final uploaded = <_UploadedPostMedia>[];
    try {
      for (var index = 0; index < selected.length; index++) {
        uploaded.add(await _uploadMedia(
          file: selected[index],
          userId: user.id,
          postId: postId,
          audience: audience,
          index: index,
        ));
      }

      final items = uploaded.map((e) => e.dbItem).toList(growable: false);
      String firstUrl(String type) => items
          .where((item) => item['type'] == type)
          .map((item) => item['url']?.toString() ?? '')
          .firstWhere((url) => url.isNotEmpty, orElse: () => '');

      final firstImage = firstUrl('image');
      final firstVideo = firstUrl('video');
      final updated = Map<String, dynamic>.from(
        await db.from('posts').update(<String, dynamic>{
          'image_url': firstImage.isEmpty ? null : firstImage,
          'video_url': firstVideo.isEmpty ? null : firstVideo,
          'media_items': items,
        }).eq('id', postId).eq('user_id', user.id).select().single(),
      );
      await SecureMediaService.resolvePost(updated);
      return updated;
    } catch (_) {
      for (final item in uploaded) {
        try { await db.storage.from(item.bucket).remove(<String>[item.storagePath]); } catch (_) {}
      }
      try { await db.from('posts').delete().eq('id', postId).eq('user_id', user.id); } catch (_) {}
      rethrow;
    }
  }

  static void _validateSelection(List<PickedPostMedia> selected) {
    var selectedBytes = 0;
    for (final item in selected) {
      final isVideo = isVideoFile(item);
      final perFileLimit = isVideo ? maxVideoBytes : maxImageBytes;
      if (item.byteSize <= 0) throw StateError('media_bytes_unavailable');
      if (item.byteSize > perFileLimit) {
        throw StateError(isVideo ? 'video_too_large_80mb' : 'image_too_large_12mb');
      }
      selectedBytes += item.byteSize;
      if (selectedBytes > maxPostMediaBytes) throw StateError('post_media_too_large_150mb');
    }
  }

  static Future<void> deletePost(String postId) async {
    final db = Supabase.instance.client;
    final user = db.auth.currentUser;
    if (user == null || postId.trim().isEmpty) return;
    final row = await db.from('posts')
        .select('id,user_id,image_url,video_url,media_items')
        .eq('id', postId)
        .maybeSingle();
    if (row == null) return;
    await db.from('posts').delete().eq('id', postId);
    await SecureMediaService.removePostMedia(Map<String, dynamic>.from(row));
  }

  /// Protects public-bucket media before a post is changed from public to a
  /// restricted audience. Private -> public keeps the private object in place;
  /// signed URLs still work and avoiding an unnecessary copy is safer/cheaper.
  static Future<void> updateAudience(String postId, String newAudience) async {
    final db = Supabase.instance.client;
    final user = db.auth.currentUser;
    if (user == null) throw StateError('not_signed_in');
    final rowRaw = await db.from('posts')
        .select('id,user_id,audience,image_url,video_url,media_items')
        .eq('id', postId)
        .eq('user_id', user.id)
        .single();
    final row = Map<String, dynamic>.from(rowRaw);
    final oldAudience = row['audience']?.toString() ?? 'public';
    if (SecureMediaService.isPublicAudience(oldAudience) &&
        !SecureMediaService.isPublicAudience(newAudience)) {
      await _migrateExistingPostToPrivate(row);
    }
    await db.from('posts').update({'audience': newAudience}).eq('id', postId).eq('user_id', user.id);
  }

  static Future<void> _migrateExistingPostToPrivate(Map<String, dynamic> row) async {
    final db = Supabase.instance.client;
    final user = db.auth.currentUser!;
    final postId = row['id'].toString();
    final rawItems = row['media_items'];
    final items = rawItems is List
        ? rawItems.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];
    if (items.isEmpty) return;

    final migrated = <Map<String, dynamic>>[];
    final oldRefs = <String>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final oldUrl = item['url']?.toString() ?? '';
      if (oldUrl.isEmpty || SecureMediaService.isPrivateReference(oldUrl)) {
        migrated.add(item);
        continue;
      }
      final bytes = await db.storage.from('posts').download(_publicPostsPath(oldUrl));
      final ext = _extension(item['name']?.toString() ?? 'media.bin');
      final safeExt = ext.isEmpty ? 'bin' : ext;
      final newPath = 'posts/$postId/${user.id}/${DateTime.now().microsecondsSinceEpoch}_$i.$safeExt';
      await db.storage.from(SecureMediaService.privateBucket).uploadBinary(
        newPath,
        bytes,
        fileOptions: FileOptions(contentType: _contentType(safeExt, isVideo: item['type'] == 'video'), upsert: false),
      );
      oldRefs.add(oldUrl);
      migrated.add(<String, dynamic>{...item, 'url': SecureMediaService.privateReference(newPath)});
    }
    String firstOf(String type) => migrated
        .where((e) => e['type'] == type)
        .map((e) => e['url']?.toString() ?? '')
        .firstWhere((e) => e.isNotEmpty, orElse: () => '');
    await db.from('posts').update({
      'media_items': migrated,
      'image_url': firstOf('image').isEmpty ? null : firstOf('image'),
      'video_url': firstOf('video').isEmpty ? null : firstOf('video'),
    }).eq('id', postId).eq('user_id', user.id);
    for (final ref in oldRefs) { await SecureMediaService.removeReference(ref); }
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

  static Future<_UploadedPostMedia> _uploadMedia({
    required PickedPostMedia file,
    required String userId,
    required String postId,
    required String audience,
    required int index,
  }) async {
    final db = Supabase.instance.client;
    final ext = _extension(file.name);
    final isVideo = _videoExtensions.contains(ext);
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final safeName = _safeFileName(file.name);
    final isPublic = SecureMediaService.isPublicAudience(audience);
    final bucket = isPublic ? 'posts' : SecureMediaService.privateBucket;
    final storagePath = isPublic
        ? '$userId/posts/${timestamp}_${index}_$safeName'
        : 'posts/$postId/$userId/${timestamp}_${index}_$safeName';
    final perFileLimit = isVideo ? maxVideoBytes : maxImageBytes;
    final actualSize = await uploadPickedPostMedia(
      client: db,
      bucket: bucket,
      storagePath: storagePath,
      source: file.source,
      maxBytes: perFileLimit,
      tooLargeError: isVideo ? 'video_too_large_80mb' : 'image_too_large_12mb',
      contentType: _contentType(ext, isVideo: isVideo),
    );
    final storedRef = isPublic
        ? db.storage.from(bucket).getPublicUrl(storagePath)
        : SecureMediaService.privateReference(storagePath);
    return _UploadedPostMedia(
      bucket: bucket,
      storagePath: storagePath,
      byteSize: actualSize,
      dbItem: <String, dynamic>{
        'type': isVideo ? 'video' : 'image',
        'url': storedRef,
        'name': file.name,
      },
    );
  }

  static String _extension(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  static String _safeFileName(String name) {
    final sanitized = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (sanitized.isEmpty) return 'media.bin';
    return sanitized.length > 90 ? sanitized.substring(sanitized.length - 90) : sanitized;
  }

  static String _contentType(String ext, {required bool isVideo}) {
    if (isVideo) {
      switch (ext) {
        case 'mov': return 'video/quicktime';
        case 'm4v': return 'video/x-m4v';
        case 'webm': return 'video/webm';
        default: return 'video/mp4';
      }
    }
    switch (ext) {
      case 'png': return 'image/png';
      case 'webp': return 'image/webp';
      case 'gif': return 'image/gif';
      case 'heic': return 'image/heic';
      case 'heif': return 'image/heif';
      default: return 'image/jpeg';
    }
  }
}

class _UploadedPostMedia {
  final String bucket;
  final String storagePath;
  final int byteSize;
  final Map<String, dynamic> dbItem;
  const _UploadedPostMedia({
    required this.bucket,
    required this.storagePath,
    required this.byteSize,
    required this.dbItem,
  });
}
