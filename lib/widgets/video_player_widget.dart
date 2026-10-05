import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:zameel/theme/app_theme.dart';
import '../services/media_cache_service.dart';
import '../services/video_source_service.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final ValueChanged<bool>? onControlsVisibilityChanged;

  const VideoPlayerWidget(
      {super.key, required this.videoUrl, this.onControlsVisibilityChanged});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  Object? _error;
  bool _isInitialized = false;
  bool _muted = true;
  bool _pausedByUser = false;
  bool _visible = false;
  bool _active = true;
  bool _starting = false;
  Timer? _visibilityTimer;
  bool _controlsVisible = true;
  Timer? _controlsTimer;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisibility());
    _visibilityTimer = Timer.periodic(
        const Duration(milliseconds: 300), (_) => _checkVisibility());
  }

  void _checkVisibility() {
    if (!mounted) return;
    final box = context.findRenderObject();
    var visible = false;
    if (_active &&
        (ModalRoute.of(context)?.isCurrent ?? true) &&
        box is RenderBox &&
        box.hasSize) {
      final rect = box.localToGlobal(Offset.zero) & box.size;
      final viewport = Offset.zero & MediaQuery.sizeOf(context);
      final overlap = rect.intersect(viewport);
      visible = rect.height > 0 &&
          rect.width > 0 &&
          !overlap.isEmpty &&
          overlap.height >= rect.height * .55 &&
          overlap.width >= rect.width * .55;
    }
    if (_visible != visible) {
      _visible = visible;
      if (!visible) {
        _controller?.pause().catchError((_) {});
      } else if (_isInitialized && !_pausedByUser) {
        _controller?.play().catchError((_) {});
      }
    }
    if (visible && !_starting && !_isInitialized && _error == null)
      _initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _checkVisibility();
  }

  Future<void> _initialize() async {
    if (_starting) return;
    _starting = true;
    final generation = ++_generation;
    VideoPlayerController? created;
    try {
      final rawUrl = widget.videoUrl.trim();
      final controller = await VideoSourceService.controller(rawUrl);
      created = controller;
      if (!mounted || generation != _generation) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      await controller.initialize().timeout(const Duration(seconds: 15));
      await controller.setVolume(_muted ? 0 : 1);
      await controller.setLooping(true);
      controller.addListener(_refreshProgress);
      if (!mounted || generation != _generation || _controller != controller)
        return;
      setState(() => _isInitialized = true);
      if (_visible &&
          _active &&
          !_pausedByUser &&
          (ModalRoute.of(context)?.isCurrent ?? true)) {
        await controller.play();
      }
      _scheduleControlsHide();
    } catch (e) {
      created?.removeListener(_refreshProgress);
      await created?.dispose();
      if (!mounted || generation != _generation) return;
      _controller = null;
      setState(() => _error = e);
    } finally {
      if (generation == _generation) _starting = false;
    }
  }

  @override
  void didUpdateWidget(covariant VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (MediaCacheService.identity(oldWidget.videoUrl) ==
        MediaCacheService.identity(widget.videoUrl)) return;
    _generation++;
    _starting = false;
    _pausedByUser = false;
    _controlsTimer?.cancel();
    _controller?.removeListener(_refreshProgress);
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
    _error = null;
    _checkVisibility();
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _visibilityTimer?.cancel();
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
        _pausedByUser = true;
        await controller.pause();
        _showControls(permanent: true);
      } else {
        _pausedByUser = false;
        await controller.play();
        _scheduleControlsHide();
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  DateTime? _lastUiRefresh;

  void _refreshProgress() {
    final refreshAt = DateTime.now();
    if (mounted &&
        (_lastUiRefresh == null ||
            refreshAt.difference(_lastUiRefresh!) >=
                const Duration(milliseconds: 200))) {
      _lastUiRefresh = refreshAt;
      setState(() {});
    }
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
    return value.inHours > 0
        ? '${value.inHours}:$minutes:$seconds'
        : '$minutes:$seconds';
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
        color: AppTheme.adaptiveSurfaceAlt,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 42),
            const SizedBox(height: 8),
            const Text('تعذر تشغيل الفيديو', textAlign: TextAlign.center),
            TextButton(
                onPressed: () {
                  setState(() {
                    _error = null;
                    _isInitialized = false;
                  });
                  _checkVisibility();
                },
                child: const Text('إعادة المحاولة')),
            const SizedBox(height: 4),
            Text('تحقق من اتصال الإنترنت وحاول مرة أخرى',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.muted, fontSize: 12)),
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
      aspectRatio: controller.value.aspectRatio == 0
          ? 16 / 9
          : controller.value.aspectRatio,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller))),
            if (controller.value.isBuffering ||
                controller.value.position == Duration.zero)
              const Center(child: CircularProgressIndicator()),
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
                        controller.value.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
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
                    icon: Icon(_muted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded),
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
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(190),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text(_time(controller.value.position),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11)),
                        Expanded(
                          child: VideoProgressIndicator(
                            controller,
                            allowScrubbing: true,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 12),
                            colors: const VideoProgressColors(
                                playedColor: AppTheme.primary,
                                bufferedColor: Colors.white38,
                                backgroundColor: Colors.white24),
                          ),
                        ),
                        Text('-${_time(_remaining(controller))}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11)),
                      ],
                    ),
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
