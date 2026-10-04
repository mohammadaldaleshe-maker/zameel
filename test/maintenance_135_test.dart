import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zameel/theme/app_theme.dart';
import 'package:zameel/widgets/profile_image_cropper.dart';

Future<Uint8List> _image() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
      const Rect.fromLTWH(0, 0, 100, 100), Paint()..color = Colors.red);
  canvas.drawRect(
      const Rect.fromLTWH(100, 0, 100, 100), Paint()..color = Colors.blue);
  final picture = recorder.endRecording();
  final image = await picture.toImage(200, 100);
  picture.dispose();
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

void main() {
  test('compact typography keeps the system accessibility scale', () {
    expect(const CompactTextScaler(TextScaler.noScaling).scale(20), 18);
    expect(const CompactTextScaler(TextScaler.linear(2)).scale(20), 36);
  });
  for (final cover in [false, true]) {
    testWidgets('crop saves the displayed ${cover ? 'cover' : 'avatar'} frame',
        (tester) async {
      late Uint8List original;
      await tester.runAsync(() async {
        original = await _image();
      });
      Uint8List? result;
      final savedResult = Completer<Uint8List?>();
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () async {
                        result = await Navigator.push<Uint8List>(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ProfileImageCropper(
                                    bytes: original,
                                    cover: cover,
                                    arabic: false)));
                        savedResult.complete(result);
                      },
                      child: const Text('Open'))))));
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final cropFrame = find.byKey(const ValueKey('profileCropFrame'));
      for (var attempt = 0;
          attempt < 100 && cropFrame.evaluate().isEmpty;
          attempt++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();
      }
      expect(cropFrame, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      // Excessive dragging must clamp at image bounds, rather than exposing blank pixels.
      final gesture = find.byKey(const ValueKey('profileCropFrame'));
      await tester.drag(gesture, const Offset(1000, 0));
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.text('Save image'));
      });
      for (var attempt = 0;
          attempt < 200 && !savedResult.isCompleted;
          attempt++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(savedResult.isCompleted, isTrue,
          reason: 'Save must return the cropped image');
      await tester.pumpAndSettle();
      expect(result, isNotNull);
      await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(result!);
        final saved = (await codec.getNextFrame()).image;
        codec.dispose();
        expect(saved.width, cover ? 1500 : 900);
        expect(saved.height, cover ? 750 : 900);
        final pixels =
            (await saved.toByteData(format: ui.ImageByteFormat.rawRgba))!
                .buffer
                .asUint8List();
        expect(pixels[3], 255);
        expect(pixels[pixels.length - 1], 255);
        if (!cover) {
          final center =
              ((saved.height ~/ 2) * saved.width + saved.width ~/ 2) * 4;
          expect(pixels[center], (Colors.red.toARGB32() >> 16) & 0xff);
          expect(pixels[center + 2], Colors.red.toARGB32() & 0xff);
        }
        saved.dispose();
      });
      expect(tester.takeException(), isNull);
    });
  }
}
