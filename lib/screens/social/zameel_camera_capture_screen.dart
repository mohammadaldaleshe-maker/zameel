import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class ZameelCameraCaptureScreen extends StatefulWidget {
  final Duration maxDuration;
  const ZameelCameraCaptureScreen({super.key, this.maxDuration = const Duration(seconds: 120)});
  @override State<ZameelCameraCaptureScreen> createState() => _ZameelCameraCaptureScreenState();
}

class _ZameelCameraCaptureScreenState extends State<ZameelCameraCaptureScreen> {
  CameraController? _controller;
  Timer? _timer;
  bool _initializing = true, _recording = false;
  int _seconds = 0;
  String? _error;
  @override void initState() { super.initState(); _init(); }
  Future<void> _init() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('No camera available');
      final camera = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cameras.first);
      final c = CameraController(camera, ResolutionPreset.high, enableAudio: true);
      await c.initialize();
      if (!mounted) { await c.dispose(); return; }
      setState(() { _controller = c; _initializing = false; });
    } catch (e) { if (mounted) setState(() { _error = e.toString(); _initializing = false; }); }
  }
  Future<void> _start() async {
    final c = _controller; if (c == null || !c.value.isInitialized || _recording) return;
    try {
      await c.startVideoRecording();
      if (!mounted) return;
      setState(() { _recording = true; _seconds = 0; });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
        if (!mounted) return;
        setState(() => _seconds++);
        if (_seconds >= widget.maxDuration.inSeconds) await _stop();
      });
    } catch (e) { if (mounted) _showError(e); }
  }
  Future<void> _stop() async {
    final c = _controller; if (c == null || !_recording) return;
    _timer?.cancel(); _timer = null;
    try { final file = await c.stopVideoRecording(); if (mounted) Navigator.pop(context, file); }
    catch (e) { if (mounted) _showError(e); }
    finally { if (mounted) setState(() => _recording = false); }
  }
  void _showError(Object e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر استخدام الكاميرا: $e')));
  @override void dispose() { _timer?.cancel(); _controller?.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    if (_initializing) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) return Scaffold(appBar: AppBar(title: const Text('الكاميرا')), body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('تعذر فتح الكاميرا\n$_error', textAlign: TextAlign.center))));
    final c = _controller!;
    return Scaffold(backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(_recording ? 'تسجيل Clip • ${_seconds}s' : 'تصوير Clip')), body: Stack(fit: StackFit.expand, children: [
      Center(child: AspectRatio(aspectRatio: c.value.aspectRatio, child: CameraPreview(c))),
      Positioned(bottom: 32, left: 0, right: 0, child: Center(child: GestureDetector(onTap: _recording ? _stop : _start, child: Container(width: 82, height: 82, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 5)), child: Container(margin: const EdgeInsets.all(7), decoration: BoxDecoration(shape: BoxShape.circle, color: _recording ? Colors.red : Colors.white))))))),
      if (!_recording) const Positioned(bottom: 128, left: 0, right: 0, child: Text('اضغط لبدء التسجيل • الحد الأقصى 120 ثانية', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
    ]));
  }
}
