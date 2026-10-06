import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import '../../platform/video_controller_factory.dart';

class StoryMediaDraft {
  final XFile file;
  final String type, audience;
  const StoryMediaDraft(this.file, this.type, this.audience);
}

class StoryMediaEditor extends StatefulWidget {
  final XFile file;
  final bool video;
  final String audience;
  const StoryMediaEditor(
      {super.key,
      required this.file,
      required this.video,
      required this.audience});
  @override
  State<StoryMediaEditor> createState() => _StoryMediaEditorState();
}

class _StoryMediaEditorState extends State<StoryMediaEditor> {
  static const channel = MethodChannel('zameel/media_export');
  final _audio = AudioPlayer();
  VideoPlayerController? _video;
  Uint8List? _image;
  String? _audioPath, _audioName, _output;
  double _start = 0,
      _duration = 15,
      _audioLength = 15,
      _audioVolume = 1,
      _originalVolume = 0;
  double _visualLength = 45;
  bool _busy = false, _ready = false, _visualReady = false;
  late String _audience = widget.audience;
  @override
  void initState() {
    super.initState();
    _loadVisual();
  }

  Future<void> _loadVisual() async {
    if (widget.video)
      await _preview(widget.file.path);
    else {
      final bytes = await widget.file.readAsBytes();
      if (mounted)
        setState(() {
          _image = bytes;
          _visualReady = true;
        });
    }
  }

  Future<bool> _preview(String path) async {
    final controller = videoControllerFromLocalPath(path);
    try {
      await controller.initialize();
      await controller.setVolume(1);
      await controller.setLooping(true);
      if (!mounted) {
        await controller.dispose();
        return false;
      }
      final old = _video;
      setState(() {
        _video = controller;
        _visualReady = true;
        if (_output == null) {
          _visualLength = controller.value.duration.inMilliseconds / 1000;
          _duration = _duration.clamp(1, _visualLength.clamp(1, 45));
        }
      });
      await old?.dispose();
      await controller.play();
      return true;
    } catch (_) {
      await controller.dispose();
      if (mounted) _notice('تعذر معاينة الفيديو');
      return false;
    }
  }

  void _notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  void _changed() {
    _ready = false;
    _output = null;
  }

  Future<void> _pickAudio() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _notice('إضافة صوت للحالة متاحة حاليًا على أندرويد');
      return;
    }
    try {
      final selected = await FilePicker.pickFile(type: FileType.audio);
      if (selected == null || !mounted) return;
      final file = selected;
      final audioBytes = await file.readAsBytes();
      if (audioBytes.length > 30 * 1024 * 1024) {
        _notice('اختر ملفًا صوتيًا أقل من 30 ميجابايت');
        return;
      }
      setState(() => _busy = true);
      try {
        final path = await channel
            .invokeMethod<String>('cacheStoryAudio', {'bytes': audioBytes});
        if (path == null) throw StateError('empty_audio');
        await _audio.setSource(DeviceFileSource(path));
        final duration = await _audio.getDuration();
        if (duration == null || duration.inMilliseconds < 1000)
          throw StateError('invalid_audio');
        if (mounted)
          setState(() {
            _audioPath = path;
            _audioName = file.name;
            _audioLength = duration.inMilliseconds / 1000;
            _start = 0;
            _duration = _audioLength.clamp(
                1, widget.video ? _visualLength.clamp(1, 45) : 45);
            _changed();
          });
      } catch (_) {
        if (mounted) _notice('تعذر قراءة المقطع الصوتي');
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    } catch (_) {
      if (mounted) _notice('تعذر فتح الملف الصوتي. اختر ملفًا آخر.');
    }
  }

  Future<void> _removeAudio() async {
    setState(() => _busy = true);
    try {
      await _audio.stop();
      final old = _video;
      setState(() {
        _audioPath = null;
        _audioName = null;
        _video = null;
        _visualReady = false;
        _changed();
      });
      await old?.dispose();
      await _loadVisual();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _render() async {
    if (_audioPath == null) return;
    setState(() => _busy = true);
    try {
      await _video?.pause();
      await _audio.stop();
      final path = await channel.invokeMethod<String>('composeStory', {
        'path': widget.file.path,
        'audio': _audioPath,
        'image': !widget.video,
        'startMs': (_start * 1000).round(),
        'durationMs': (_duration * 1000).round(),
        'audioVolume': _audioVolume,
        'originalVolume': _originalVolume,
      });
      if (path == null) throw StateError('empty_output');
      _output = path;
      if (!await _preview(path)) throw StateError('preview_failed');
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted)
        _notice('تعذر دمج الصوت. جرّب مقطعًا آخر أو انشر دون صوت إضافي.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    _audio.dispose();
    super.dispose();
  }

  Widget _slider(String label, double value, double max,
          ValueChanged<double> change) =>
      Column(children: [
        Text(label),
        Slider(
            value: value.clamp(0, max),
            min: 0,
            max: max <= 0 ? 1 : max,
            onChanged: _busy
                ? null
                : (v) => setState(() {
                      change(v);
                      _changed();
                    })),
      ]);
  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('معاينة الحالة')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          SizedBox(
              height: MediaQuery.sizeOf(context).height * .42,
              child: _video?.value.isInitialized == true
                  ? AspectRatio(
                      aspectRatio: _video!.value.aspectRatio,
                      child: VideoPlayer(_video!))
                  : _image != null
                      ? Image.memory(_image!, fit: BoxFit.contain)
                      : const Center(child: CircularProgressIndicator())),
          if (_video != null)
            TextButton.icon(
                onPressed: () {
                  setState(() {
                    _video!.value.isPlaying ? _video!.pause() : _video!.play();
                  });
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('تشغيل / إيقاف المعاينة')),
          DropdownButtonFormField<String>(
              initialValue: _audience,
              decoration: const InputDecoration(labelText: 'خصوصية الحالة'),
              items: const [
                DropdownMenuItem(value: 'public', child: Text('العامة')),
                DropdownMenuItem(value: 'college', child: Text('الكلية')),
                DropdownMenuItem(value: 'department', child: Text('التخصص'))
              ],
              onChanged: _busy ? null : (v) => setState(() => _audience = v!)),
          TextButton.icon(
              onPressed: _busy ? null : _pickAudio,
              icon: const Icon(Icons.audio_file),
              label: Text(_audioName ?? 'إضافة مقطع صوتي من الهاتف')),
          if (_audioPath != null) ...[
            _slider('بداية المقطع: ${_start.toStringAsFixed(1)} ثانية', _start,
                (_audioLength - 1).clamp(0, _audioLength), (v) {
              _start = v;
              _duration = _duration.clamp(1, (_audioLength - v).clamp(1, 45));
            }),
            _slider(
                'المدة: ${_duration.toStringAsFixed(1)} ثانية',
                _duration,
                (_audioLength - _start)
                    .clamp(1, widget.video ? _visualLength.clamp(1, 45) : 45),
                (v) => _duration = v.clamp(1, 45)),
            _slider('صوت المقطع', _audioVolume, 1, (v) => _audioVolume = v),
            if (widget.video)
              _slider('صوت الفيديو الأصلي (صفر للكتم)', _originalVolume, 1,
                  (v) => _originalVolume = v),
            TextButton(
                onPressed: _busy ? null : _removeAudio,
                child: const Text('إزالة الصوت الإضافي')),
            FilledButton(
                onPressed: _busy ? null : _render,
                child: const Text('دمج الصوت ومعاينة النتيجة')),
          ],
          if (_busy)
            const Padding(
                padding: EdgeInsets.all(16),
                child: Column(children: [
                  CircularProgressIndicator(),
                  Text('جارٍ تجهيز الحالة…')
                ])),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: _busy ||
                      !_visualReady ||
                      (_audioPath != null && !_ready)
                  ? null
                  : () => Navigator.pop(
                      context,
                      StoryMediaDraft(
                          _output == null ? widget.file : XFile(_output!),
                          _output != null || widget.video ? 'video' : 'image',
                          _audience)),
              child: const Text('نشر الحالة')),
        ]),
      ));
}
