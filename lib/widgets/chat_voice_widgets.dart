import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import '../services/voice_recording_file.dart';

class VoiceDraft {
  final Uint8List bytes;
  const VoiceDraft(this.bytes);
}

class VoiceRecordingDialog extends StatefulWidget {
  const VoiceRecordingDialog({super.key});
  @override
  State<VoiceRecordingDialog> createState() => _VoiceRecordingDialogState();
}

class _VoiceRecordingDialogState extends State<VoiceRecordingDialog> {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  Timer? _timer;
  String? _path;
  VoiceDraft? _draft;
  bool _recording = false, _busy = false, _playing = false;
  int _seconds = 0;
  String? _error;
  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  Future<void> _start() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!await _recorder.hasPermission()) throw StateError('permission');
      _path = await VoiceRecordingFile.createPath();
      await _recorder.start(
          const RecordConfig(
              encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100),
          path: _path!);
      if (!mounted) {
        await _recorder.cancel();
        return;
      }
      setState(() {
        _recording = true;
        _seconds = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _seconds++);
        if (_seconds >= 120) _stop();
      });
    } catch (_) {
      if (mounted)
        setState(() => _error = 'تعذر التسجيل. تأكد من السماح بالميكروفون');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    if (_busy || !_recording) return;
    setState(() => _busy = true);
    _timer?.cancel();
    try {
      final path = await _recorder.stop();
      _path = path ?? _path;
      if (path == null) throw StateError('empty');
      final bytes = await XFile(path).readAsBytes();
      if (bytes.isEmpty || bytes.length > 15 * 1024 * 1024)
        throw StateError('size');
      if (mounted)
        setState(() {
          _draft = VoiceDraft(bytes);
          _recording = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _recording = false;
          _error = 'تعذر قراءة التسجيل. أعد التسجيل';
        });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _preview() async {
    try {
      if (_playing) {
        await _player.pause();
      } else {
        if (_player.state == PlayerState.paused) {
          await _player.resume();
        } else {
          await _player.play(BytesSource(_draft!.bytes, mimeType: 'audio/mp4'));
        }
      }
      if (mounted) setState(() => _playing = !_playing);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر تشغيل المعاينة');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_recorder.dispose().then((_) async {
      if (_path != null && !kIsWeb) await VoiceRecordingFile.remove(_path!);
    }));
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_busy,
      child: AlertDialog(
          title: const Text('رسالة صوتية'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
                '${_seconds ~/ 60}:${(_seconds % 60).toString().padLeft(2, '0')}'),
            const Text('الحد الأقصى دقيقتان'),
            if (_error != null)
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            if (_draft == null)
              FilledButton.icon(
                  onPressed: _busy ? null : (_recording ? _stop : _start),
                  icon: Icon(_recording ? Icons.stop : Icons.mic),
                  label: Text(_recording ? 'إيقاف التسجيل' : 'بدء التسجيل')),
            if (_draft != null)
              TextButton.icon(
                  onPressed: _preview,
                  icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                  label: const Text('معاينة التسجيل')),
          ]),
          actions: [
            TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: const Text('إلغاء')),
            if (_draft != null)
              FilledButton(
                  onPressed:
                      _busy ? null : () => Navigator.pop(context, _draft),
                  child: const Text('إرسال')),
          ]));
}

class ChatVoicePlayer extends StatefulWidget {
  final String url;
  const ChatVoicePlayer({super.key, required this.url});
  @override
  State<ChatVoicePlayer> createState() => _ChatVoicePlayerState();
}

class _ChatVoicePlayerState extends State<ChatVoicePlayer> {
  final _player = AudioPlayer();
  bool _playing = false;
  Duration _position = Duration.zero, _duration = Duration.zero;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  @override
  void initState() {
    super.initState();
    _subscriptions.add(_player.onPositionChanged.listen((v) {
      if (mounted) setState(() => _position = v);
    }));
    _subscriptions.add(_player.onDurationChanged.listen((v) {
      if (mounted) setState(() => _duration = v);
    }));
    _subscriptions.add(_player.onPlayerComplete.listen((_) {
      if (mounted)
        setState(() {
          _playing = false;
          _position = Duration.zero;
        });
    }));
  }

  Future<void> _toggle() async {
    try {
      if (_playing) {
        await _player.pause();
      } else {
        if (_player.state == PlayerState.paused) {
          await _player.resume();
        } else {
          await _player.play(UrlSource(widget.url));
        }
      }
      if (mounted) setState(() => _playing = !_playing);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر تشغيل الرسالة الصوتية')));
    }
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
            onPressed: _toggle,
            icon: Icon(_playing ? Icons.pause_circle : Icons.play_circle)),
        Text('رسالة صوتية ${_position.inSeconds}/${_duration.inSeconds} ث'),
      ]);
}
