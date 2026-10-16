import 'package:zameel/screens/stories/stories_screen.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:zameel/widgets/video_player_widget.dart';
import 'package:zameel/widgets/visibility_pulse163.dart';
import 'package:zameel/widgets/post_action161.dart';

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
  testWidgets('one shared visibility clock releases all listeners',
      (tester) async {
    var first = 0, second = 0;
    void a() => first++;
    void b() => second++;
    VisibilityPulse163.add(a);
    VisibilityPulse163.add(b);
    await tester.pump(const Duration(milliseconds: 300));
    expect(first, 1);
    expect(second, 1);
    VisibilityPulse163.remove(a);
    await tester.pump(const Duration(milliseconds: 600));
    expect(first, 1);
    expect(second, 3);
    VisibilityPulse163.remove(b);
    await tester.pump(const Duration(seconds: 1));
    expect(second, 3);
  });
  testWidgets(
      'tall video can start; hidden mounted player releases decoder and restarts',
      (tester) async {
    final original = VideoPlayerPlatform.instance;
    final fake = _VideoPlatform();
    VideoPlayerPlatform.instance = fake;
    addTearDown(() => VideoPlayerPlatform.instance = original);
    final scroll = ScrollController();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                controller: scroll,
                child: const Column(children: [
                  SizedBox(
                      height: 1600,
                      child: VideoPlayerWidget(videoUrl: '/fixture/tall.mp4')),
                  SizedBox(height: 3000),
                ])))));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(fake.serial, 1);
    expect(fake.playing[1], isTrue);
    scroll.jumpTo(2300);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
    expect(fake.disposed, contains(1));
    scroll.jumpTo(0);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(fake.serial, 2);
    expect(fake.playing[2], isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
    expect(fake.disposed, contains(2));
    expect(tester.takeException(), isNull);
    scroll.dispose();
  });
  testWidgets('likes number has a full-height separate target', (tester) async {
    var likes = 0, people = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
                child: PostAction161(
                    icon: Icons.favorite,
                    label: 'إعجاب',
                    color: Colors.blue,
                    countText: '123',
                    onPressed: () => likes++,
                    onCountTap: () => people++)))));
    final number = tester.getCenter(find.text('123'));
    await tester.tapAt(number + const Offset(0, 18));
    expect(people, 1);
    expect(likes, 0);
    await tester.tap(find.byIcon(Icons.favorite));
    expect(likes, 1);
    expect(people, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'visible story previews share one decoder and release previous preview',
      (tester) async {
    final original = VideoPlayerPlatform.instance;
    final fake = _VideoPlatform();
    VideoPlayerPlatform.instance = fake;
    addTearDown(() => VideoPlayerPlatform.instance = original);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: Row(children: [
      SizedBox(
          width: 58,
          height: 58,
          child:
              StoryCirclePreview163(story: {'videoPath': '/fixture/one.mp4'})),
      SizedBox(
          width: 58,
          height: 58,
          child:
              StoryCirclePreview163(story: {'videoPath': '/fixture/two.mp4'})),
    ]))));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(fake.serial, 1);
    await tester.pump(const Duration(seconds: 2));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(fake.serial, 2);
    expect(fake.disposed, contains(1));
    expect(fake.serial - fake.disposed.length, lessThanOrEqualTo(1));
    await tester.pumpWidget(const SizedBox());
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
    expect(fake.disposed, contains(2));
    expect(tester.takeException(), isNull);
  });
  testWidgets('four icon actions fit a narrow profile row with readable counts',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
                child: SizedBox(
                    width: 260,
                    child: Row(
                        children: List.generate(
                            4,
                            (i) => Expanded(
                                child: PostAction161(
                                    icon: Icons.favorite,
                                    label: 'إعجاب',
                                    color: Colors.blue,
                                    countText: '12345',
                                    onPressed: () {})))))))));
    expect(find.text('12345'), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });
}
