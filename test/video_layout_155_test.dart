import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:zameel/providers/language_provider.dart';
import 'package:zameel/screens/social/public_clips_strip.dart';

class _VideoPlatform extends VideoPlayerPlatform {
  int serial = 0;
  final events = <int, StreamController<VideoEvent>>{};
  final playing = <int, bool>{};
  final volume = <int, double>{};
  final disposed = <int>{};
  final plays = <int>[];
  bool defer = false;
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = ++serial;
    events[id] = StreamController<VideoEvent>();
    playing[id] = false;
    if (!defer) initialize(id);
    return id;
  }

  void initialize(int id) {
    events[id]!.add(VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 20),
        size: const Size(320, 400)));
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => events[playerId]!.stream;
  @override
  Future<void> dispose(int playerId) async {
    playing[playerId] = false;
    disposed.add(playerId);
    await events[playerId]?.close();
  }

  @override
  Future<void> play(int playerId) async {
    playing[playerId] = true;
    plays.add(playerId);
  }

  @override
  Future<void> pause(int playerId) async {
    playing[playerId] = false;
  }

  @override
  Future<void> setVolume(int playerId, double value) async {
    volume[playerId] = value;
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> seekTo(int playerId, Duration position) async {}
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
        url: 'http://localhost:54321', anonKey: 'local-test', debug: false);
  });
  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('Arabic short controls do not overlap metadata on $size',
        (tester) async {
      final original = VideoPlayerPlatform.instance;
      final fake = _VideoPlatform();
      VideoPlayerPlatform.instance = fake;
      addTearDown(() => VideoPlayerPlatform.instance = original);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.view.padding = const FakeViewPadding(bottom: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      await tester.pumpWidget(ChangeNotifierProvider(
          create: (_) => LanguageProvider(),
          child: MaterialApp(
              home: Directionality(
                  textDirection: TextDirection.rtl,
                  child: VerticalClipsViewer(clips: [
                    {
                      'id': 'local-clip',
                      'video_url': '/fake/clip.mp4',
                      'caption': 'وصف المقطع',
                      'users': {'name': 'شريك اختبار'},
                      'views_count': 2
                    }
                  ], initialIndex: 0)))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      final area =
          tester.getRect(find.byKey(const ValueKey('short-video-area')));
      final details =
          tester.getRect(find.byKey(const ValueKey('short-details')));
      expect(area.bottom, lessThanOrEqualTo(details.top));
      expect(details.bottom, lessThanOrEqualTo(size.height - 24));
      final progress = find.byType(VideoProgressIndicator);
      expect(progress, findsOneWidget);
      expect(Directionality.of(tester.element(progress)), TextDirection.ltr);
      final sound = find.byIcon(Icons.volume_up_rounded);
      expect(tester.getRect(sound).bottom, lessThan(details.top));
      for (final button
          in tester.widgetList<TextButton>(find.byType(TextButton))) {
        expect(button.style?.foregroundColor?.resolve({}), Colors.white);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(fake.playing.values.every((v) => !v), isTrue);
    });
  }
}
