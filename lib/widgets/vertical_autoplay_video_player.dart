
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/media_cache_service.dart';
import '../platform/video_controller_factory.dart';

/// Autoplay player used only by the full-screen vertical media viewers.
///
/// It is intentionally separate from the shared feed/profile video player so media
/// and WebRTC call flows keep their previous 052 behavior. The controller is
/// paused when the app or this route is no longer active and is disposed as
/// soon as the current vertical page is replaced.
class VerticalAutoplayVideoPlayer extends StatefulWidget {
  final String videoUrl;

  const VerticalAutoplayVideoPlayer({
    super.key,
    required this.videoUrl,
  });

  @override
  State<VerticalAutoplayVideoPlayer> createState() =>
      _VerticalAutoplayVideoPlayerState();
}

class _VerticalAutoplayVideoPlayerState
    extends State<VerticalAutoplayVideoPlayer> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  Object? _error;
  bool _initialized = false;
  bool _muted = false;
  bool _pausedByUser = false;
  bool _appActive = true;
  bool _routeCurrent = true;
  bool _syncScheduled = false;

  bool get _shouldPlay =>
      _initialized && _appActive && _routeCurrent && !_pausedByUser;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void didUpdateWidget(covariant VerticalAutoplayVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _replaceController();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _captureRouteState();
  }

  void _captureRouteState() {
    final current = ModalRoute.of(context)?.isCurrent ?? true;
    if (_routeCurrent == current) return;
    _routeCurrent = current;
    _schedulePlaybackSync();
  }

  void _schedulePlaybackSync() {
    if (_syncScheduled) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (mounted) _syncPlayback();
    });
  }

  Future<void> _replaceController() async {
    final previous = _controller;
    _controller = null;
    _initialized = false;
    _error = null;
    _pausedByUser = false;
    try {
      await previous?.pause();
    } catch (_) {}
    await previous?.dispose();
    if (mounted) setState(() {});
    await _initialize();
  }

  Future<void> _initialize() async {
    final rawUrl = widget.videoUrl.trim();
    if (rawUrl.isEmpty) {
      if (mounted) setState(() => _error = const FormatException('empty_video_url'));
      return;
    }

    // Full-screen playback downloads once into the bounded cache, then plays
    // the local file. The former stream + prefetch pair could request the same
    // Supabase object twice on first playback.
    final cachedPath = kIsWeb
        ? null
        : await MediaCacheService.localPathForUrl(
            rawUrl,
            downloadIfMissing: true,
          );
    final controller = !kIsWeb && cachedPath != null
        ? videoControllerFromLocalPath(cachedPath)
        : VideoPlayerController.networkUrl(Uri.parse(rawUrl));
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(_muted ? 0 : 1);
      if (!mounted || _controller != controller) {
        await controller.dispose();
        return;
      }
      _initialized = true;
      if (_shouldPlay) await controller.play();
      if (mounted) setState(() {});
    } catch (error) {
      if (_controller == controller) {
        try {
          await controller.dispose();
        } catch (_) {}
        _controller = null;
      }
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _syncPlayback() async {
    final controller = _controller;
    if (controller == null || !_initialized) return;
    try {
      if (_shouldPlay) {
        if (!controller.value.isPlaying) await controller.play();
      } else if (controller.value.isPlaying) {
        await controller.pause();
      }
      if (mounted) setState(() {});
    } catch (_) {
      // A disposed route can race with an async player command. Disposal is
      // authoritative, so no user-facing error is needed for that race.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    _syncPlayback();
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !_initialized) return;
    try {
      if (controller.value.isPlaying) {
        _pausedByUser = true;
        await controller.pause();
      } else {
        _pausedByUser = false;
        if (_appActive && _routeCurrent) await controller.play();
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null || !_initialized) return;
    _muted = !_muted;
    await controller.setVolume(_muted ? 0 : 1);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    _controller = null;
    controller?.pause();
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _captureRouteState();
    final controller = _controller;

    if (_error != null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.white70, size: 42),
            SizedBox(height: 8),
            Text('تعذر تشغيل الفيديو', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    if (controller == null || !_initialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final ratio = controller.value.aspectRatio == 0
        ? 16 / 9
        : controller.value.aspectRatio;
    return AspectRatio(
      aspectRatio: ratio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          VideoPlayer(controller),
          Center(
            child: Material(
              color: Colors.black45,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: controller.value.isPlaying ? 'إيقاف' : 'تشغيل',
                onPressed: _togglePlayback,
                icon: Icon(
                  controller.value.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ),
            ),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: IconButton.filledTonal(
              onPressed: _toggleMute,
              icon: Icon(
                _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
