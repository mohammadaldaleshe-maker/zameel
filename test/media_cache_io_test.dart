import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zameel/services/media_cache_service_io.dart' as cache;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUp(() async { directory = await Directory.systemTemp.createTemp('zameel-cache-test-'); });
  tearDown(() async {
    await cache.configureMediaCacheForTesting();
    await directory.delete(recursive: true);
  });

  test('a cache-only miss does not wait for an in-flight download', () async {
    final started = Completer<void>();
    final response = Completer<http.Response>();
    var requests = 0;
    await cache.configureMediaCacheForTesting(directory: () async => directory,
      user: () => 'alice', clientFactory: () => MockClient((_) {
        requests++;
        if (!started.isCompleted) started.complete();
        return response.future;
      }));
    const url = 'https://project.supabase.co/storage/v1/object/sign/posts/one.jpg?token=one';
    final download = cache.localPathForUrl(url);
    await started.future;
    try {
      expect(await cache.localPathForUrl(url, downloadIfMissing: false)
          .timeout(const Duration(seconds: 1)), isNull);
    } finally {
      response.complete(http.Response('image bytes', 200));
    }
    final path = await download;
    expect(path, isNotNull);
    expect(await cache.localPathForUrl(url, downloadIfMissing: false), path);
    expect(requests, 1);
  });

  test('rotated signatures coalesce one request and share the disk file', () async {
    final response = Completer<http.Response>();
    var requests = 0;
    await cache.configureMediaCacheForTesting(directory: () async => directory,
      user: () => 'alice', clientFactory: () => MockClient((_) {
        requests++;
        return response.future;
      }));
    const base = 'https://project.supabase.co/storage/v1/object/sign/posts/two.jpg';
    final a = cache.localPathForUrl('$base?token=one');
    final b = cache.localPathForUrl('$base?token=two');
    response.complete(http.Response('same image', 200));
    final paths = await Future.wait([a, b]);
    expect(paths.first, isNotNull);
    expect(paths.first, paths.last);
    expect(requests, 1);
  });

  test('a failed HTTP request leaves no completed cache entry', () async {
    var requests = 0;
    await cache.configureMediaCacheForTesting(directory: () async => directory,
      user: () => 'alice', clientFactory: () => MockClient((_) async {
        requests++;
        return http.Response('forbidden', 403);
      }));
    const url = 'https://project.supabase.co/storage/v1/object/sign/posts/denied.jpg';
    expect(await cache.localPathForUrl(url), isNull);
    expect(await cache.localPathForUrl(url, downloadIfMissing: false), isNull);
    expect(requests, 1);
  });

  test('a signed object is never reused across accounts', () async {
    var user = 'alice';
    await cache.configureMediaCacheForTesting(directory: () async => directory,
      user: () => user, clientFactory: () => MockClient((_) async => http.Response('bytes', 200)));
    const url = 'https://project.supabase.co/storage/v1/object/sign/posts/private.jpg';
    expect(await cache.localPathForUrl(url), isNotNull);
    user = 'bob';
    expect(await cache.localPathForUrl(url, downloadIfMissing: false), isNull);
  });

  test('logout while downloading prevents resurrecting a cleared private file', () async {
    var user = 'alice';
    final started = Completer<void>();
    final response = Completer<http.Response>();
    await cache.configureMediaCacheForTesting(directory: () async => directory,
      user: () => user, clientFactory: () => MockClient((_) {
        started.complete();
        return response.future;
      }));
    const url = 'https://project.supabase.co/storage/v1/object/sign/posts/pending.jpg';
    final download = cache.localPathForUrl(url);
    await started.future;
    user = 'bob';
    await cache.clearPrivateMediaForUser('alice');
    response.complete(http.Response('private bytes', 200));
    expect(await download, isNull);
    user = 'alice';
    expect(await cache.localPathForUrl(url, downloadIfMissing: false), isNull);
  });
}
