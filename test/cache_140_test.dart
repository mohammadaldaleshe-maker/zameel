import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:zameel/services/media_cache_service_io.dart' as cache;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'cache cleanup evicts oldest entries under size limit and keeps active downloads',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('zameel-cache-140-');
    await cache.configureMediaCacheForTesting(
        directory: () async => directory, user: () => 'alice');
    try {
      final oldest = File('${directory.path}/old.jpg');
      final newest = File('${directory.path}/new.jpg');
      for (final file in [oldest, newest]) {
        final handle = await file.open(mode: FileMode.write);
        await handle.truncate(150 * 1024 * 1024);
        await handle.close();
      }
      await oldest.setLastModified(
          DateTime.now().subtract(const Duration(minutes: 10)));
      final active = File('${directory.path}/active.part');
      await active.writeAsString('in progress');
      final expired = File('${directory.path}/expired.jpg');
      await expired.writeAsString('expired');
      await expired
          .setLastModified(DateTime.now().subtract(const Duration(hours: 7)));
      await cache.cleanup();
      expect(await oldest.exists(), isFalse);
      expect(await newest.exists(), isTrue);
      expect(await active.exists(), isTrue);
      expect(await expired.exists(), isFalse);
    } finally {
      await cache.configureMediaCacheForTesting();
      await directory.delete(recursive: true);
    }
  });
}
