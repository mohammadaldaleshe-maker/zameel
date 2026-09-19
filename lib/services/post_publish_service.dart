import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PickedPostMedia {
  final XFile source;
  final int byteSize;

  const PickedPostMedia({required this.source, required this.byteSize});

  String get name => source.name;
  String get path => source.path;
  int get lengthSync => byteSize;
  Future<Uint8List> readAsBytes() => source.readAsBytes();
}

/// Additive publisher for normal feed posts that can contain up to ten mixed
/// media items. Engagement still targets the single row in `posts`, so likes,
/// comments, replies, saves, shares and notifications keep using the same
/// `posts.id` as before.
class PostPublishService {
  static const int maxMediaItems = 10;
  static const int maxImageBytes = 12 * 1024 * 1024;
  static const int maxVideoBytes = 80 * 1024 * 1024;
  static const int maxPostMediaBytes = 150 * 1024 * 1024;

  static const List<String> allowedExtensions = <String>[
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'heic',
    'heif',
    'mp4',
    'mov',
    'm4v',
    'webm',
  ];

  static const Set<String> _videoExtensions = <String>{
    'mp4',
    'mov',
    'm4v',
    'webm',
  };

  static bool isVideoFile(PickedPostMedia file) =>
      _videoExtensions.contains(_extension(file.name));

  static bool isSupportedFile(PickedPostMedia file) =>
      allowedExtensions.contains(_extension(file.name));

  /// Uses the native mixed-media picker so one selection can contain
  /// multiple photos and videos. file_picker 12.x returns the list directly.
  static Future<List<PickedPostMedia>> pickMultipleMedia({
    int limit = maxMediaItems,
  }) async {
    if (limit <= 0) return const <PickedPostMedia>[];
    final picked = await ImagePicker().pickMultipleMedia(imageQuality: 90);
    if (picked.isEmpty) return const <PickedPostMedia>[];

    final selected = <PickedPostMedia>[];
    for (final source in picked.take(limit)) {
      final item = PickedPostMedia(
        source: source,
        byteSize: await source.length(),
      );
      if (isSupportedFile(item)) selected.add(item);
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
    if (cleanText.isEmpty && selected.isEmpty) {
      throw ArgumentError('empty_post');
    }

    final uploaded = <Map<String, dynamic>>[];
    final uploadedPaths = <String>[];
    var uploadedBytes = 0;

    try {
      for (var index = 0; index < selected.length; index++) {
        final item = await _uploadMedia(
          file: selected[index],
          userId: user.id,
          index: index,
        );
        uploaded.add(item.publicItem);
        uploadedPaths.add(item.storagePath);
        uploadedBytes += item.byteSize;
        if (uploadedBytes > maxPostMediaBytes) {
          throw StateError('post_media_too_large_150mb');
        }
      }

      final firstImage = uploaded
          .where((item) => item['type'] == 'image')
          .map((item) => item['url']?.toString() ?? '')
          .firstWhere((url) => url.isNotEmpty, orElse: () => '');
      final firstVideo = uploaded
          .where((item) => item['type'] == 'video')
          .map((item) => item['url']?.toString() ?? '')
          .firstWhere((url) => url.isNotEmpty, orElse: () => '');

      // Keep the legacy type/image_url/video_url columns populated so older
      // Zameel builds can still show at least the first selected media item.
      final legacyType = uploaded.isEmpty
          ? 'text'
          : (uploaded.first['type']?.toString() == 'video' ? 'video' : 'image');

      final row = <String, dynamic>{
        'user_id': user.id,
        'type': legacyType,
        'text_ar': cleanText,
        'text_en': cleanText,
        'image_url': firstImage.isEmpty ? null : firstImage,
        'video_url': firstVideo.isEmpty ? null : firstVideo,
        'media_items': uploaded,
        'likes_count': 0,
        'comments_count': 0,
        'audience': audience,
      };

      return Map<String, dynamic>.from(
        await db.from('posts').insert(row).select().single(),
      );
    } catch (_) {
      // If one of the later uploads or the DB insert fails, remove only the
      // newly uploaded objects. Existing posts/media are never touched.
      if (uploadedPaths.isNotEmpty) {
        try {
          await db.storage.from('posts').remove(uploadedPaths);
        } catch (_) {}
      }
      rethrow;
    }
  }

  static Future<_UploadedPostMedia> _uploadMedia({
    required PickedPostMedia file,
    required String userId,
    required int index,
  }) async {
    final db = Supabase.instance.client;
    final ext = _extension(file.name);
    final isVideo = _videoExtensions.contains(ext);
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final safeName = _safeFileName(file.name);
    final storagePath = '$userId/posts/${timestamp}_${index}_$safeName';
    final contentType = _contentType(ext, isVideo: isVideo);
    final perFileLimit = isVideo ? maxVideoBytes : maxImageBytes;

    var uploaded = false;
    var actualSize = 0;
    if (!kIsWeb && file.path.isNotEmpty) {
      final localFile = File(file.path);
      if (await localFile.exists()) {
        actualSize = await localFile.length();
        if (actualSize > perFileLimit) {
          throw StateError(
            isVideo ? 'video_too_large_80mb' : 'image_too_large_12mb',
          );
        }
        await db.storage.from('posts').upload(
              storagePath,
              localFile,
              fileOptions: FileOptions(
                contentType: contentType,
                cacheControl: '31536000',
                upsert: false,
              ),
            );
        uploaded = true;
      }
    }

    // Fall back to XFile bytes for providers that do not expose a durable path.
    if (!uploaded) {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) throw StateError('media_bytes_unavailable');
      actualSize = bytes.length;
      if (bytes.length > perFileLimit) {
        throw StateError(
          isVideo ? 'video_too_large_80mb' : 'image_too_large_12mb',
        );
      }
      await db.storage.from('posts').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              cacheControl: '31536000',
              upsert: false,
            ),
          );
    }

    final url = db.storage.from('posts').getPublicUrl(storagePath);
    return _UploadedPostMedia(
      storagePath: storagePath,
      byteSize: actualSize,
      publicItem: <String, dynamic>{
        'type': isVideo ? 'video' : 'image',
        'url': url,
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
    return sanitized.length > 90
        ? sanitized.substring(sanitized.length - 90)
        : sanitized;
  }

  static String _contentType(String ext, {required bool isVideo}) {
    if (isVideo) {
      switch (ext) {
        case 'mov':
          return 'video/quicktime';
        case 'm4v':
          return 'video/x-m4v';
        case 'webm':
          return 'video/webm';
        default:
          return 'video/mp4';
      }
    }

    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      default:
        return 'image/jpeg';
    }
  }

}

class _UploadedPostMedia {
  final String storagePath;
  final int byteSize;
  final Map<String, dynamic> publicItem;

  const _UploadedPostMedia({
    required this.storagePath,
    required this.byteSize,
    required this.publicItem,
  });
}
