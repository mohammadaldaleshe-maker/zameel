import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Keeps non-public media out of public Storage buckets while preserving the
/// existing String URL fields used throughout the UI.
///
/// Public content still stores ordinary public URLs. Non-public content stores
/// an opaque `zameel-private://...` reference. Before a row reaches a media
/// widget, this service exchanges that reference for a short-lived signed URL.
class SecureMediaService {
  SecureMediaService._();

  static const String privateBucket = 'zameel_private_media';
  static const Duration signedUrlLifetime = Duration(minutes: 55);
  static SupabaseClient get _db => Supabase.instance.client;
  static final Map<String, _SignedUrlCacheEntry> _signedCache = {};

  static bool isPublicAudience(String? audience) =>
      (audience ?? 'public').trim().toLowerCase() == 'public';

  static String privateReference(String path) => Uri(
        scheme: 'zameel-private',
        host: privateBucket,
        queryParameters: <String, String>{'path': path},
      ).toString();

  static bool isPrivateReference(String? value) =>
      value != null && value.startsWith('zameel-private://');

  static _PrivateRef? _parsePrivateReference(String? value) {
    if (!isPrivateReference(value)) return null;
    try {
      final uri = Uri.parse(value!);
      final path = uri.queryParameters['path'];
      if (uri.host.isEmpty || path == null || path.trim().isEmpty) return null;
      return _PrivateRef(bucket: uri.host, path: path);
    } catch (_) {
      return null;
    }
  }

  static Future<String> resolve(String? value) async {
    final raw = value?.trim() ?? '';
    var ref = _parsePrivateReference(raw);
    if (ref == null) {
      final publicRef = _parseSupabaseStorageUrl(raw);
      if (publicRef != null &&
          (publicRef.bucket == 'posts' || publicRef.bucket == 'graduation_book')) {
        // 074 turns these legacy buckets private. Existing database rows still
        // contain their old getPublicUrl() strings, so transparently exchange
        // them for signed URLs instead of requiring a destructive data rewrite.
        ref = publicRef;
      }
    }
    if (ref == null) return raw;

    final now = DateTime.now();
    final cached = _signedCache[raw];
    if (cached != null && cached.expiresAt.isAfter(now.add(const Duration(minutes: 3)))) {
      return cached.url;
    }

    final url = await _db.storage
        .from(ref.bucket)
        .createSignedUrl(ref.path, signedUrlLifetime.inSeconds);
    _signedCache[raw] = _SignedUrlCacheEntry(
      url: url,
      expiresAt: now.add(signedUrlLifetime),
    );
    return url;
  }

  static Future<void> resolvePost(Map<String, dynamic> post) async {
    post['image_url'] = await resolve(post['image_url']?.toString());
    post['video_url'] = await resolve(post['video_url']?.toString());
    final raw = post['media_items'];
    if (raw is List) {
      final resolved = <Map<String, dynamic>>[];
      for (final entry in raw) {
        if (entry is! Map) continue;
        final item = Map<String, dynamic>.from(entry);
        item['url'] = await resolve(item['url']?.toString());
        resolved.add(item);
      }
      post['media_items'] = resolved;
    }
  }

  static Future<void> resolvePosts(Iterable<Map<String, dynamic>> posts) async {
    await Future.wait(posts.map(resolvePost));
  }

  static Future<void> resolveStory(Map<String, dynamic> story) async {
    story['media_url'] = await resolve(story['media_url']?.toString());
  }

  static Future<void> resolveClip(Map<String, dynamic> clip) async {
    clip['video_url'] = await resolve(clip['video_url']?.toString());
  }

  static Future<void> resolveBookImages(Iterable<dynamic> images) async {
    for (final raw in images) {
      if (raw is Map && raw['url'] != null) {
        raw['url'] = await resolve(raw['url']?.toString());
      }
    }
  }

  /// Removes a Storage object referenced either by a private marker or by a
  /// Supabase public object URL. Non-Supabase URLs are ignored deliberately.
  static Future<void> removeReference(String? value) async {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return;

    final privateRef = _parsePrivateReference(raw);
    if (privateRef != null) {
      await _safeRemove(privateRef.bucket, privateRef.path);
      _signedCache.remove(raw);
      return;
    }

    final publicRef = _parseSupabaseStorageUrl(raw);
    if (publicRef != null) {
      await _safeRemove(publicRef.bucket, publicRef.path);
    }
  }

  static Future<void> removePostMedia(Map<String, dynamic> post) async {
    final refs = <String>{};
    void add(dynamic value) {
      final s = value?.toString().trim() ?? '';
      if (s.isNotEmpty) refs.add(s);
    }

    add(post['image_url']);
    add(post['video_url']);
    final raw = post['media_items'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) add(item['url']);
      }
    }
    for (final ref in refs) {
      await removeReference(ref);
    }
  }

  static Future<void> _safeRemove(String bucket, String path) async {
    // Storage and PostgREST cannot share one transaction. Retry transient
    // cleanup failures immediately so ordinary content deletion does not leave
    // paid Storage objects behind just because one request briefly failed.
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await _db.storage.from(bucket).remove(<String>[path]);
        return;
      } catch (_) {
        if (attempt == 2) return;
        await Future<void>.delayed(Duration(milliseconds: 250 * (attempt + 1)));
      }
    }
  }

  static _PrivateRef? _parseSupabaseStorageUrl(String value) {
    try {
      final uri = Uri.parse(value);
      final segments = uri.pathSegments;
      final objectIndex = segments.indexOf('object');
      if (objectIndex < 0 || objectIndex + 3 >= segments.length) return null;
      final accessKind = segments[objectIndex + 1];
      if (accessKind != 'public' && accessKind != 'sign') return null;
      final bucket = segments[objectIndex + 2];
      final path = segments.sublist(objectIndex + 3).join('/');
      if (bucket.isEmpty || path.isEmpty) return null;
      return _PrivateRef(bucket: bucket, path: Uri.decodeFull(path));
    } catch (_) {
      return null;
    }
  }
}

class _PrivateRef {
  final String bucket;
  final String path;
  const _PrivateRef({required this.bucket, required this.path});
}

class _SignedUrlCacheEntry {
  final String url;
  final DateTime expiresAt;
  const _SignedUrlCacheEntry({required this.url, required this.expiresAt});
}
