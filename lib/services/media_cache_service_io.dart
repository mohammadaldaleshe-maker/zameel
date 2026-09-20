import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

// Social media is immutable because every upload gets a unique object path.
// Keeping it locally for two weeks prevents the same Supabase CDN object from
// being downloaded again whenever the user revisits the feed.
const Duration _maxAge = Duration(days: 14);
const int _maxTotalBytes = 300 * 1024 * 1024;
const int _maxSingleFileBytes = 80 * 1024 * 1024;

final Map<String, Future<String?>> _inFlight = <String, Future<String?>>{};
Future<void>? _cleanupFuture;

Future<Directory> _cacheDirectory() async {
  final root = await getTemporaryDirectory();
  final dir = Directory('${root.path}${Platform.pathSeparator}zameel_media_cache_v1');
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

String _stableCacheIdentity(String url) {
  try {
    final uri = Uri.parse(url);
    // Supabase signed URLs rotate their `token` query value while pointing to
    // the same immutable object. Cache by object path rather than signature so
    // refreshing a signed URL does not download the same video/image again.
    if (uri.path.contains('/storage/v1/object/sign/')) {
      return uri.replace(query: '').toString();
    }
  } catch (_) {}
  return url;
}

String _cacheName(String url) {
  final identity = _stableCacheIdentity(url);
  final digest = sha1.convert(Uri.encodeFull(identity).codeUnits).toString();
  var extension = 'cache';
  try {
    final path = Uri.parse(identity).path;
    final last = path.split('/').last;
    final dot = last.lastIndexOf('.');
    if (dot >= 0 && dot + 1 < last.length) {
      final candidate = last.substring(dot + 1).toLowerCase();
      if (RegExp(r'^[a-z0-9]{1,6}$').hasMatch(candidate)) extension = candidate;
    }
  } catch (_) {}
  return '$digest.$extension';
}

Future<File> _fileFor(String url) async {
  final dir = await _cacheDirectory();
  return File('${dir.path}${Platform.pathSeparator}${_cacheName(url)}');
}

Future<bool> _isFresh(File file) async {
  try {
    if (!await file.exists()) return false;
    final stat = await file.stat();
    if (stat.size <= 0 || DateTime.now().difference(stat.modified) > _maxAge) {
      await file.delete().catchError((_) => file);
      return false;
    }
    // Touching the file lets cleanup use modification time as a practical LRU.
    await file.setLastModified(DateTime.now());
    return true;
  } catch (_) {
    return false;
  }
}

Future<String?> localPathForUrl(
  String url, {
  bool downloadIfMissing = true,
}) async {
  final normalized = url.trim();
  if (normalized.isEmpty ||
      !(normalized.startsWith('http://') || normalized.startsWith('https://'))) {
    return null;
  }

  final existing = _inFlight[normalized];
  if (existing != null) return existing;

  final task = _resolve(normalized, downloadIfMissing: downloadIfMissing);
  _inFlight[normalized] = task;
  try {
    return await task;
  } finally {
    _inFlight.remove(normalized);
  }
}

Future<String?> _resolve(
  String url, {
  required bool downloadIfMissing,
}) async {
  final target = await _fileFor(url);
  if (await _isFresh(target)) return target.path;
  if (!downloadIfMissing) return null;

  final temp = File('${target.path}.part');
  final client = http.Client();
  try {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        if (await temp.exists()) await temp.delete();
        final request = http.Request('GET', Uri.parse(url));
        final response = await client.send(request).timeout(const Duration(seconds: 18));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          await response.stream.drain<void>();
          if (attempt < 2) {
            await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
            continue;
          }
          return null;
        }

        final expected = response.contentLength;
        if (expected != null && expected > _maxSingleFileBytes) {
          await response.stream.drain<void>();
          return null;
        }

        final sink = temp.openWrite();
        var total = 0;
        var tooLarge = false;
        try {
          await for (final chunk in response.stream) {
            total += chunk.length;
            if (total > _maxSingleFileBytes) {
              tooLarge = true;
              break;
            }
            sink.add(chunk);
          }
        } finally {
          await sink.flush();
          await sink.close();
        }
        if (tooLarge || total <= 0) {
          if (await temp.exists()) await temp.delete();
          return null;
        }
        if (await target.exists()) await target.delete();
        await temp.rename(target.path);
        unawaited(_scheduleCleanup());
        return target.path;
      } catch (_) {
        if (await temp.exists()) await temp.delete().catchError((_) => temp);
        if (attempt < 2) {
          await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
          continue;
        }
      }
    }
    return null;
  } finally {
    client.close();
  }
}

Future<void> storeBytes(String url, Uint8List bytes) async {
  final normalized = url.trim();
  if (normalized.isEmpty || bytes.isEmpty || bytes.length > _maxSingleFileBytes) return;
  if (!(normalized.startsWith('http://') || normalized.startsWith('https://'))) return;
  try {
    final target = await _fileFor(normalized);
    await target.writeAsBytes(bytes, flush: true);
    await target.setLastModified(DateTime.now());
    unawaited(_scheduleCleanup());
  } catch (_) {}
}

Future<void> _scheduleCleanup() {
  final current = _cleanupFuture;
  if (current != null) return current;
  final future = cleanup();
  _cleanupFuture = future.whenComplete(() {
    _cleanupFuture = null;
  });
  return _cleanupFuture!;
}

Future<void> cleanup() async {
  try {
    final dir = await _cacheDirectory();
    final files = <File>[];
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      if (entity.path.endsWith('.part')) {
        // A process kill can leave an unfinished download behind. Keep a very
        // recent part file (another request may still own it) but remove stale
        // ones so temporary storage cannot grow forever.
        try {
          final stat = await entity.stat();
          if (DateTime.now().difference(stat.modified) > const Duration(hours: 1)) {
            await entity.delete();
          }
        } catch (_) {}
        continue;
      }
      files.add(entity);
    }

    final now = DateTime.now();
    final kept = <({File file, FileStat stat})>[];
    for (final file in files) {
      try {
        final stat = await file.stat();
        if (stat.size <= 0 || now.difference(stat.modified) > _maxAge) {
          await file.delete();
        } else {
          kept.add((file: file, stat: stat));
        }
      } catch (_) {}
    }

    kept.sort((a, b) => b.stat.modified.compareTo(a.stat.modified));
    var total = 0;
    for (final item in kept) {
      total += item.stat.size;
      if (total > _maxTotalBytes) {
        try {
          await item.file.delete();
        } catch (_) {}
      }
    }
  } catch (_) {}
}
