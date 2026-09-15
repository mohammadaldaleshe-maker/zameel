import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:zameel/theme/app_theme.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerWidget({super.key, required this.videoUrl});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  Object? _error;
  bool _isInitialized = false;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final uri = Uri.parse(widget.videoUrl);
      final controller = VideoPlayerController.networkUrl(uri);
      _controller = controller;
      await controller.initialize();
      await controller.setLooping(true);
      if (!mounted) return;
      setState(() => _isInitialized = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !_isInitialized) return;
    try {
      if (controller.value.isPlaying) {
        await controller.pause();
      } else {
        await controller.play();
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
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
                  controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
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
              icon: Icon(_muted ? Icons.volume_off_rounded : Icons.volume_up_rounded),
            ),
          ),
        ],
      ),
    );
  }
}
