import '../../services/shorts_video_preparer.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/feature_control.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../services_social.dart';
import '../../theme/app_theme.dart';
import '../../platform/video_controller_factory.dart';

class ClipCreateScreen extends StatefulWidget {
  final bool isArabic;

  const ClipCreateScreen({
    super.key,
    required this.isArabic,
  });

  @override
  State<ClipCreateScreen> createState() => _ClipCreateScreenState();
}

class _ClipCreateScreenState extends State<ClipCreateScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _busy = false;

  bool get ar => widget.isArabic;

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pick(ImageSource source) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 120),
      );
      if (file == null) return;

      final bytes = kIsWeb ? await file.readAsBytes() : null;
      if (kIsWeb && (bytes == null || bytes.isEmpty)) {
        _message(
            ar ? 'تعذر قراءة ملف الفيديو.' : 'Could not read the video file.');
        return;
      }

      final duration = await _readDuration(file, bytes);
      if (duration != null && duration > const Duration(seconds: 120)) {
        _message(
          ar
              ? 'مدة الشورتس تتجاوز 120 ثانية. اختر أو سجل فيديو أقصر.'
              : 'The Short is longer than 120 seconds. Choose or record a shorter video.',
        );
        return;
      }

      if (!mounted) return;
      final published = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => _ClipPreviewPublishScreen(
            isArabic: ar,
            file: file,
            bytes: bytes,
            duration: duration,
          ),
        ),
      );
      if (published == true && mounted) {
        Navigator.pop(context, true);
      }
    } catch (_) {
      _message(
        ar
            ? 'تعذر فتح الكاميرا أو اختيار الفيديو. تحقق من صلاحية الكاميرا والميكروفون وحاول مجددًا.'
            : 'Could not open the camera or choose a video. Check camera and microphone permissions and try again.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Duration?> _readDuration(XFile file, Uint8List? bytes) async {
    VideoPlayerController? controller;
    try {
      if (kIsWeb) {
        Uri? uri;
        final path = file.path;
        if (path.startsWith('http://') ||
            path.startsWith('https://') ||
            path.startsWith('blob:') ||
            path.startsWith('data:')) {
          uri = Uri.tryParse(path);
        }
        if (uri == null && bytes != null) {
          uri = Uri.dataFromBytes(bytes, mimeType: _mimeType(file.name));
        }
        if (uri == null) return null;
        controller = VideoPlayerController.networkUrl(uri);
      } else {
        controller = videoControllerFromLocalPath(file.path);
      }
      await controller.initialize();
      return controller.value.duration;
    } catch (_) {
      return null;
    } finally {
      await controller?.dispose();
    }
  }

  String _mimeType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.m4v')) return 'video/x-m4v';
    return 'video/mp4';
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: AppTheme.signatureGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: AppTheme.adaptiveMuted.shade600),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(ar ? 'إضافة شورتس' : 'Add Short'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    ar
                        ? 'أنشئ شورتس جديدًا مباشرة دون فتح الشورتسات الموجودة.'
                        : 'Create a new clip directly without opening existing clips.',
                    style: TextStyle(color: AppTheme.adaptiveMuted.shade700),
                  ),
                  const SizedBox(height: 18),
                  _actionCard(
                    icon: Icons.videocam_rounded,
                    title: ar ? 'تسجيل شورتس الآن' : 'Record a clip now',
                    subtitle: ar ? 'بحد أقصى 120 ثانية' : 'Up to 120 seconds',
                    onTap: () => _pick(ImageSource.camera),
                  ),
                  const SizedBox(height: 12),
                  _actionCard(
                    icon: Icons.video_library_rounded,
                    title: ar ? 'اختيار من الهاتف' : 'Choose from phone',
                    subtitle: ar
                        ? 'اختر فيديو لا تتجاوز مدته 120 ثانية'
                        : 'Choose a video up to 120 seconds long',
                    onTap: () => _pick(ImageSource.gallery),
                  ),
                ],
              ),
              if (_busy)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x33000000),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClipPreviewPublishScreen extends StatefulWidget {
  final bool isArabic;
  final XFile file;
  final Uint8List? bytes;
  final Duration? duration;

  const _ClipPreviewPublishScreen({
    required this.isArabic,
    required this.file,
    required this.bytes,
    required this.duration,
  });

  @override
  State<_ClipPreviewPublishScreen> createState() =>
      _ClipPreviewPublishScreenState();
}

class _ClipPreviewPublishScreenState extends State<_ClipPreviewPublishScreen> {
  final TextEditingController _caption = TextEditingController();
  XFile? _cover;
  VideoPlayerController? _video;
  bool _initializing = true;
  bool _publishing = false;
  String? _previewError;

  bool get ar => widget.isArabic;

  @override
  void initState() {
    super.initState();
    _initializePreview();
  }

  @override
  void dispose() {
    _caption.dispose();
    _video?.dispose();
    super.dispose();
  }

  String _mimeType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.m4v')) return 'video/x-m4v';
    return 'video/mp4';
  }

  Future<void> _initializePreview() async {
    try {
      if (kIsWeb) {
        Uri? uri;
        final path = widget.file.path;
        if (path.startsWith('http://') ||
            path.startsWith('https://') ||
            path.startsWith('blob:') ||
            path.startsWith('data:')) {
          uri = Uri.tryParse(path);
        }
        if (uri == null && widget.bytes != null) {
          uri = Uri.dataFromBytes(
            widget.bytes!,
            mimeType: _mimeType(widget.file.name),
          );
        }
        if (uri == null) throw StateError('preview_url_unavailable');
        _video = VideoPlayerController.networkUrl(uri);
      } else {
        _video = videoControllerFromLocalPath(widget.file.path);
      }
      await _video!.initialize();
      await _video!.setLooping(true);
      await _video!.play();
    } catch (error) {
      _previewError = error.toString();
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  int get _durationSeconds {
    final duration = widget.duration ?? _video?.value.duration;
    if (duration == null || duration.inMilliseconds <= 0) return 0;
    return math.max(1, (duration.inMilliseconds / 1000).ceil());
  }

  Future<void> _publish() async {
    if (_publishing) return;
    if (_durationSeconds <= 0 || _durationSeconds > 120) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ar
                ? 'لا يمكن نشر شورتس أطول من 120 ثانية.'
                : 'A Short longer than 120 seconds cannot be published.',
          ),
        ),
      );
      return;
    }

    if (kIsWeb && _cover == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ar
              ? 'اختر صورة غلاف للفيديو قبل النشر.'
              : 'Choose a cover image before publishing.')));
      return;
    }
    setState(() => _publishing = true);
    PreparedShort? prepared;
    try {
      prepared = await prepareShortVideo(widget.file, cover: _cover);
      final id = await ZameelSocialService.createClipFile(
        file: prepared.video,
        cover: prepared.cover,
        caption: _caption.text.trim(),
        durationSeconds: _durationSeconds,
        audience: 'public',
      );
      if (id == null) throw StateError('clip_not_created');
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(FeatureControl.errorMessage(
                error,
                ar
                    ? 'تعذر نشر الشورتس. تحقق من الاتصال وحاول مجددًا.'
                    : 'Could not publish the clip. Check your connection and try again.')),
          ),
        );
      }
    } finally {
      await prepared?.cleanup();
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(ar ? 'معاينة الشورتس' : 'Short preview'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(
                  aspectRatio: _video?.value.isInitialized == true
                      ? _video!.value.aspectRatio
                      : 9 / 16,
                  child: ColoredBox(
                    color: Colors.black,
                    child: _initializing
                        ? const Center(child: CircularProgressIndicator())
                        : _previewError != null ||
                                _video?.value.isInitialized != true
                            ? Center(
                                child: Icon(
                                  Icons.video_library_outlined,
                                  color: Colors.white,
                                  size: 56,
                                ),
                              )
                            : Stack(
                                fit: StackFit.expand,
                                children: [
                                  VideoPlayer(_video!),
                                  Center(
                                    child: IconButton.filledTonal(
                                      onPressed: () {
                                        final controller = _video;
                                        if (controller == null) return;
                                        if (controller.value.isPlaying) {
                                          controller.pause();
                                        } else {
                                          controller.play();
                                        }
                                        setState(() {});
                                      },
                                      icon: Icon(
                                        _video!.value.isPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                ar
                    ? 'المدة: $_durationSeconds ثانية من 120'
                    : 'Duration: $_durationSeconds of 120 seconds',
                style: TextStyle(color: AppTheme.adaptiveMuted.shade600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _caption,
                maxLength: 300,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: ar ? 'وصف اختياري' : 'Optional caption',
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                  onPressed: _publishing
                      ? null
                      : () async {
                          final cover = await ImagePicker().pickImage(
                              source: ImageSource.gallery,
                              maxWidth: 720,
                              maxHeight: 1280,
                              imageQuality: 85);
                          if (mounted && cover != null)
                            setState(() => _cover = cover);
                        },
                  icon: const Icon(Icons.image_outlined),
                  label: Text(ar
                      ? (_cover == null
                          ? (kIsWeb
                              ? 'اختيار غلاف للفيديو'
                              : 'اختيار غلاف اختياري')
                          : 'تم اختيار الغلاف — تغييره')
                      : (_cover == null
                          ? (kIsWeb
                              ? 'Choose a video cover'
                              : 'Choose optional cover')
                          : 'Cover selected — change'))),
              Text(ar
                  ? 'الشورتس الجديدة متاحة للعامة'
                  : 'New Shorts are public'),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _publishing ? null : _publish,
                icon: _publishing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.publish_rounded),
                label: Text(ar ? 'نشر الشورتس' : 'Publish Short'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _publishing ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.replay_rounded),
                label: Text(ar
                    ? 'إلغاء واختيار فيديو آخر'
                    : 'Cancel and choose another video'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
