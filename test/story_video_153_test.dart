import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:zameel/screens/stories/stories_screen.dart';

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
  testWidgets(
      'only active story plays; previous audio stops on switch and viewer disposal',
      (tester) async {
    final original = VideoPlayerPlatform.instance;
    final fake = _VideoPlatform();
    VideoPlayerPlatform.instance = fake;
    addTearDown(() {
      VideoPlayerPlatform.instance = original;
    });
    Widget frame(bool first) => MaterialApp(
            home: Scaffold(
                body: Row(children: [
          Expanded(
              child: StoryVideoPlayer(
                  key: const ValueKey('one'),
                  path: 'blob:first',
                  active: first)),
          Expanded(
              child: StoryVideoPlayer(
                  key: const ValueKey('two'),
                  path: 'blob:second',
                  active: !first)),
        ])));
    await tester.pumpWidget(frame(true));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(fake.playing[1], true);
    expect(fake.playing[2], false);
    expect(fake.plays.contains(2), false);
    await tester.pumpWidget(frame(false));
    for (var i = 0; i < 3; i++) {
      await tester.pump();
    }
    expect(fake.playing[1], false);
    expect(fake.volume[1], 0);
    expect(fake.playing[2], true);
    // Cancellation can involve futures outside the widget fake clock.
    // Drain frames and real asynchronous work, retaining the strict disposal check.
    await tester.runAsync(() async {
      await tester.pumpWidget(const SizedBox());
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (fake.disposed.length < 2 && DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 10));
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    expect(fake.playing.values.every((v) => !v), true);
    expect(fake.disposed, {1, 2});
  });
  testWidgets(
      'video finishing initialization after page switch never starts offscreen',
      (tester) async {
    final original = VideoPlayerPlatform.instance;
    final fake = _VideoPlatform()..defer = true;
    VideoPlayerPlatform.instance = fake;
    addTearDown(() {
      VideoPlayerPlatform.instance = original;
    });
    await tester.pumpWidget(const MaterialApp(
        home: StoryVideoPlayer(path: 'blob:delayed', active: true)));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(
        home: StoryVideoPlayer(path: 'blob:delayed', active: false)));
    fake.initialize(1);
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    expect(fake.playing[1], false);
    expect(fake.plays, isEmpty);
    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 3; i++) {
      await tester.pump();
    }
  });
}
