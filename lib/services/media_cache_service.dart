import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'media_cache_service_stub.dart'
    if (dart.library.io) 'media_cache_service_io.dart' as platform;

/// Small, bounded temporary cache for Zameel social media.
///
/// The cache lives in the operating-system temporary/cache directory, so the
/// OS may purge it at any time. Zameel also evicts old/large entries itself.
class MediaCacheService {
  MediaCacheService._();

  static Future<String?> localPathForUrl(
    String url, {
    bool downloadIfMissing = true,
  }) =>
      platform.localPathForUrl(
        url,
        downloadIfMissing: downloadIfMissing,
      );

  static Future<void> storeBytes(String url, Uint8List bytes) =>
      platform.storeBytes(url, bytes);

  static Future<void> prefetch(Iterable<String> urls, {int limit = 4}) async {
    final selected = <String>[];
    for (final raw in urls) {
      final url = raw.trim();
      if (url.isEmpty || selected.contains(url)) continue;
      selected.add(url);
      if (selected.length >= limit) break;
    }
    if (selected.isEmpty) return;
    await Future.wait(
      selected.map((url) => localPathForUrl(url)),
      eagerError: false,
    );
  }

  static Future<void> cleanup() => platform.cleanup();

  /// Wait for a just-uploaded public Supabase object to be reachable from its
  /// public URL before the client advertises it as ready. This avoids the
  /// short CDN propagation window that previously produced "تعذر عرض الفيديو"
  /// immediately after publishing a clip.
  static Future<bool> waitUntilRemoteReady(
    String url, {
    int attempts = 8,
    Duration retryDelay = const Duration(milliseconds: 450),
  }) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme) return false;
    final client = http.Client();
    try {
      for (var i = 0; i < attempts; i++) {
        try {
          final response = await client.head(uri).timeout(
                const Duration(seconds: 4),
              );
          if (response.statusCode >= 200 && response.statusCode < 400) {
            return true;
          }

          // Some CDN/storage edges do not support HEAD consistently. Fall
          // back to a one-byte ranged GET so a valid public object is not
          // incorrectly treated as unavailable just because HEAD was denied.
          if (response.statusCode == 400 ||
              response.statusCode == 403 ||
              response.statusCode == 405) {
            final request = http.Request('GET', uri)
              ..headers['Range'] = 'bytes=0-0';
            final streamed = await client.send(request).timeout(
                  const Duration(seconds: 4),
                );
            if (streamed.statusCode >= 200 && streamed.statusCode < 400) {
              return true;
            }
            await streamed.stream.drain<void>();
          }
        } catch (_) {
          // Retry below. A freshly uploaded public object can briefly return a
          // network/edge miss even though Storage has accepted the bytes.
        }
        if (i + 1 < attempts) await Future<void>.delayed(retryDelay);
      }
      return false;
    } finally {
      client.close();
    }
  }
}
