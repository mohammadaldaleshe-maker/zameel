
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:zameel/theme/app_theme.dart';
import '../services/media_cache_service.dart';
import '../platform/video_controller_factory.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final ValueChanged<bool>? onControlsVisibilityChanged;

  const VideoPlayerWidget({super.key, required this.videoUrl, this.onControlsVisibilityChanged});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  Object? _error;
  bool _isInitialized = false;
  bool _muted = false;
  bool _controlsVisible = true;
  Timer? _controlsTimer;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final rawUrl = widget.videoUrl.trim();
      // Download once, then play the local file. The previous implementation
      // streamed the remote video while simultaneously prefetching it, which
      // could double Supabase cached-egress for every first playback.
      final localPath = kIsWeb
          ? null
          : await MediaCacheService.localPathForUrl(
              rawUrl,
              downloadIfMissing: true,
            );
      final controller = !kIsWeb && localPath != null
          ? videoControllerFromLocalPath(localPath)
          : VideoPlayerController.networkUrl(Uri.parse(rawUrl));
      _controller = controller;
      await controller.initialize();
      await controller.setLooping(true);
      controller.addListener(_refreshProgress);
      if (!mounted) return;
      setState(() => _isInitialized = true);
      _scheduleControlsHide();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _controller?.removeListener(_refreshProgress);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !_isInitialized) return;
    try {
      if (controller.value.isPlaying) {
        await controller.pause();
        _showControls(permanent: true);
      } else {
        await controller.play();
        _scheduleControlsHide();
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _refreshProgress() {
    if (mounted) setState(() {});
  }

  void _showControls({bool permanent = false}) {
    _controlsTimer?.cancel();
    if (mounted) setState(() => _controlsVisible = true);
    widget.onControlsVisibilityChanged?.call(true);
    if (!permanent) _scheduleControlsHide();
  }

  void _scheduleControlsHide() {
    _controlsTimer?.cancel();
    if (_controller?.value.isPlaying != true) return;
    _controlsTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _controlsVisible = false);
      widget.onControlsVisibilityChanged?.call(false);
    });
  }

  void _toggleControls() {
    if (_controlsVisible) {
      _controlsTimer?.cancel();
      setState(() => _controlsVisible = false);
      widget.onControlsVisibilityChanged?.call(false);
    } else {
      _showControls();
    }
  }

  String _time(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return value.inHours > 0 ? '${value.inHours}:$minutes:$seconds' : '$minutes:$seconds';
  }

  Duration _remaining(VideoPlayerController controller) {
    final value = controller.value.duration - controller.value.position;
    return value.isNegative ? Duration.zero : value;
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null || !_isInitialized) return;
    _muted = !_muted;
    await controller.setVolume(_muted ? 0 : 1);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (_error != null) {
      return Container(
        color: Colors.black12,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 42),
            const SizedBox(height: 8),
            const Text('تعذر تشغيل الفيديو', textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('تحقق من اتصال الإنترنت وحاول مرة أخرى', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.muted, fontSize: 12)),
          ],
        ),
      );
    }

    if (controller == null || !_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    return AspectRatio(
      aspectRatio: controller.value.aspectRatio == 0 ? 16 / 9 : controller.value.aspectRatio,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            VideoPlayer(controller),
            AnimatedOpacity(
              opacity: _controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: Center(
            child: Material(
              color: Colors.black45,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: controller.value.isPlaying ? 'إيقاف' : 'تشغيل',
                onPressed: _togglePlayback,
                icon: Icon(
                  controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ),
            ),
          ),
              ),
            ),
            Positioned(
            right: 8,
            bottom: 42,
            child: AnimatedOpacity(
              opacity: _controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: IconButton.filledTonal(
                  onPressed: _toggleMute,
                  icon: Icon(_muted ? Icons.volume_off_rounded : Icons.volume_up_rounded),
                ),
              ),
            ),
          ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 4,
              child: AnimatedOpacity(
                opacity: _controlsVisible ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: IgnorePointer(
                  ignoring: !_controlsVisible,
                  child: Row(
                    children: [
                      Text(_time(controller.value.position), style: const TextStyle(color: Colors.white, fontSize: 11)),
                      Expanded(
                        child: VideoProgressIndicator(
                          controller,
                          allowScrubbing: true,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          colors: const VideoProgressColors(playedColor: AppTheme.primary, bufferedColor: Colors.white38, backgroundColor: Colors.white24),
                        ),
                      ),
                      Text('-${_time(_remaining(controller))}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
