import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zameel/services/media_cache_service_io.dart' as cache;
import 'package:zameel/widgets/post_media_gallery.dart';

void main() {
  testWidgets(
      'landscape image frame fits its image instead of reserving portrait height',
      (tester) async {
    late Directory directory;
    await tester.runAsync(() async {
      directory = await Directory.systemTemp.createTemp('zameel-layout161');
      await cache.configureMediaCacheForTesting(
          directory: () async => directory, user: () => 'layout161');
    });
    const url = 'https://fixture.test/photo161.png';
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(Colors.green, BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(400, 200);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await cache.storeBytes(url, bytes!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: SizedBox(
                    width: 400,
                    child: PostMediaGallery(
                        height: 600, post: const {'image_url': url}))))));
    for (var i = 0; i < 25; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
      if (find.byType(Image).evaluate().isNotEmpty &&
          tester.getSize(find.byType(PostMediaGallery)).height < 500) break;
    }
    expect(find.byType(Image), findsOneWidget);
    final size = tester.getSize(find.byType(PostMediaGallery));
    expect(size.height, closeTo((size.width - 3) / 2 + 3, 5));
    expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.contain);
    await tester.pumpWidget(const SizedBox());
    PaintingBinding.instance.imageCache.clear();
    await tester.runAsync(() async {
      await cache.configureMediaCacheForTesting();
      await directory.delete(recursive: true);
    });
  });
}
