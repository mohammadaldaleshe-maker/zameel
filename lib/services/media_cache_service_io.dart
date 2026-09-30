import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show visibleForTesting, debugPrint;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';
import 'media_identity.dart';

// Social media is immutable because every upload gets a unique object path.
// The app-support directory survives ordinary cache purges and app restarts.
const Duration _maxAge = Duration(hours: 6);

final Map<String, Future<String?>> _inFlight = <String, Future<String?>>{};
Future<void>? _cleanupFuture;
DateTime? _lastCleanup;

Future<Directory> Function()? _testDirectory;
http.Client Function()? _testClient;
String? Function()? _testUser;
String? _currentUser() => _testUser != null ? _testUser!() :
    Supabase.instance.client.auth.currentUser?.id;

@visibleForTesting
Future<void> configureMediaCacheForTesting({
  Future<Directory> Function()? directory,
  http.Client Function()? clientFactory,
  String? Function()? user,
}) async {
  await _cleanupFuture;
  _testDirectory = directory;
  _testClient = clientFactory;
  _testUser = user;
  _inFlight.clear();
  _lastCleanup = null;
}

Future<Directory> _cacheDirectory() async {
  if (_testDirectory != null) return _testDirectory!();
  final root = await getApplicationSupportDirectory();
  final dir = Directory('${root.path}${Platform.pathSeparator}zameel_media_cache_v2');
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

String _stableCacheIdentity(String url) =>
    mediaIdentity(url, storageOrigin: ZameelConfig.supabaseUrl);

String _cacheName(String url) {
  final identity = _stableCacheIdentity(url);
  final signed = isStorageMedia(url);
  final userId = signed ? _currentUser() : null;
  // Never reuse a private signed object across accounts on the same device.
  final digest = sha1.convert(utf8.encode('${userId ?? ''}:$identity')).toString();
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
  final prefix = signed ? 'signed_${userId ?? 'guest'}_' : '';
  return '$prefix$digest.$extension';
}

Future<void> clearPrivateMediaForUser(String userId) async {
  if (userId.isEmpty) return;
  try {
    final dir = await _cacheDirectory();
    await for (final entity in dir.list()) {
      if (entity is File && entity.uri.pathSegments.last.startsWith('signed_${userId}_')) {
        await entity.delete();
      }
    }
  } catch (_) {}
}

Future<File> _fileFor(String url) async {
  final dir = await _cacheDirectory();
  return File('${dir.path}${Platform.pathSeparator}${_cacheName(url)}');
}

// Reuse files written by 119-122 rather than making the first upgrade download
// every already-cached image again. Signed legacy files remain account scoped.
Future<String?> _adoptLegacy(String value, File target) async {
  try {
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    final candidates = <String>{};
    if (uri.scheme != 'zameel-private') candidates.add(value);
    if (uri.scheme == 'zameel-private') {
      final root = Uri.parse(ZameelConfig.supabaseUrl);
      candidates.add(root.replace(path: '/storage/v1/object/sign/${uri.host}/${uri.queryParameters['path'] ?? ''}').toString());
    } else if (uri.path.contains('/storage/v1/object/public/posts/') ||
        uri.path.contains('/storage/v1/object/public/graduation_book/')) {
      candidates.add(uri.replace(path: uri.path.replaceFirst('/object/public/', '/object/sign/'), query: '').toString());
    }
    for (final candidate in candidates) {
      final oldUri = Uri.parse(candidate);
      final signed = oldUri.path.contains('/storage/v1/object/sign/');
      final identity = signed ? oldUri.replace(query: '').toString() : candidate;
      final user = signed ? _currentUser() : null;
      final digest = sha1.convert(utf8.encode('${user ?? ''}:$identity')).toString();
      final extension = oldUri.path.split('.').last.toLowerCase();
      final safeExt = RegExp(r'^[a-z0-9]{1,6}$').hasMatch(extension) ? extension : 'cache';
      final prefix = signed ? 'signed_${user ?? 'guest'}_' : '';
      final old = File('${target.parent.path}/$prefix$digest.$safeExt');
      if (old.path != target.path && await _isFresh(old)) {
        await old.copy(target.path);
        return target.path;
      }
    }
  } catch (_) {}
  return null;
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
      !(normalized.startsWith('http://') || normalized.startsWith('https://') ||
        normalized.startsWith('zameel-private://'))) {
    return null;
  }

  // A cache-only probe must never wait for an unrelated active download.
  final target = await _fileFor(normalized);
  if (await _isFresh(target)) return target.path;
  final adopted = await _adoptLegacy(normalized, target);
  if (adopted != null) return adopted;
  if (!downloadIfMissing) return null;
  final identity = target.path;
  final existing = _inFlight[identity];
  if (existing != null) return existing;
  final task = _resolve(normalized, target: target);
  _inFlight[identity] = task;
  try {
    return await task;
  } finally {
    if (identical(_inFlight[identity], task)) _inFlight.remove(identity);
  }
}

Future<String?> _resolve(
  String url, {
  required File target,
}) async {
  final watch = Stopwatch()..start();
  final owner = _currentUser();
  if (await _isFresh(target)) return target.path;

  final temp = File('${target.path}.part');
  final client = _testClient?.call() ?? http.Client();
  try {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        if (await temp.exists()) await temp.delete();
        final request = http.Request('GET', Uri.parse(url));
        final response = await client.send(request).timeout(const Duration(seconds: 12));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          await response.stream.drain<void>();
          if (response.statusCode >= 400 && response.statusCode < 500) return null;
          if (attempt < 1) {
            await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
            continue;
          }
          return null;
        }

        final sink = temp.openWrite();
        var total = 0;
        try {
          await for (final chunk in response.stream.timeout(const Duration(seconds: 12))) {
            total += chunk.length;
            sink.add(chunk);
          }
        } finally {
          await sink.flush();
          await sink.close();
        }
        if (total <= 0) {
          if (await temp.exists()) await temp.delete();
          return null;
        }
        if (isStorageMedia(url) && _currentUser() != owner) {
          if (await temp.exists()) await temp.delete();
          return null;
        }
        if (await target.exists()) await target.delete();
        await temp.rename(target.path);
        debugPrint('Zameel media: downloaded $total bytes in ${watch.elapsedMilliseconds}ms');
        unawaited(_scheduleCleanup());
        return target.path;
      } catch (_) {
        if (await temp.exists()) await temp.delete().catchError((_) => temp);
        if (attempt < 1) {
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
  if (normalized.isEmpty || bytes.isEmpty) return;
  if (!(normalized.startsWith('http://') || normalized.startsWith('https://') ||
        normalized.startsWith('zameel-private://'))) return;
  try {
    final target = await _fileFor(normalized);
    await target.writeAsBytes(bytes, flush: true);
    await target.setLastModified(DateTime.now());
    unawaited(_scheduleCleanup());
  } catch (_) {}
}

Future<void> _scheduleCleanup() {
  if (_lastCleanup != null && DateTime.now().difference(_lastCleanup!) < const Duration(minutes: 15)) {
    return Future<void>.value();
  }
  _lastCleanup = DateTime.now();
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
    for (final file in files) {
      try {
        final stat = await file.stat();
        if (stat.size <= 0 || now.difference(stat.modified) > _maxAge) {
          await file.delete();
        }
      } catch (_) {}
    }
  } catch (_) {}
}
