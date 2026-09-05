import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';

// ============================================================
// STORIES WIDGET (معدل بالكامل)
// ============================================================

class StoriesWidget extends StatefulWidget {
  final List<Map<String, dynamic>> stories;

  const StoriesWidget({
    super.key,
    required this.stories,
  });

  @override
  State<StoriesWidget> createState() => _StoriesWidgetState();
}

class _StoriesWidgetState extends State<StoriesWidget> {
  // ============================================================
  // إضافة حالة جديدة
  // ============================================================

  void _addMyStory() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isArabic = languageProvider.isArabic;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Directionality(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isArabic ? 'أضف حالة جديدة' : 'Add a new story',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StoryTypeButton(
                      icon: Icons.text_fields_rounded,
                      label: isArabic ? 'نص' : 'Text',
                      color: Color(0xFF18D3C3),
                      onTap: () {
                        Navigator.pop(context);
                        _showTextStoryDialog();
                      },
                    ),
                    _StoryTypeButton(
                      icon: Icons.image_rounded,
                      label: isArabic ? 'صورة' : 'Image',
                      color: Colors.green,
                      onTap: () {
                        Navigator.pop(context);
                        _pickImageStory();
                      },
                    ),
                    _StoryTypeButton(
                      icon: Icons.videocam_rounded,
                      label: isArabic ? 'فيديو' : 'Video',
                      color: Colors.red,
                      onTap: () {
                        Navigator.pop(context);
                        _pickVideoStory();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // إضافة حالة نصية
  // ============================================================

  void _showTextStoryDialog() {
    final controller = TextEditingController();
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isArabic = languageProvider.isArabic;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            title: Text(
              isArabic ? 'حالة جديدة' : 'New Story',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: TextField(
              controller: controller,
              maxLines: 4,
              autofocus: true,
              decoration: InputDecoration(
                hintText: isArabic ? 'اكتب ما تريد مشاركته...' : 'Write what you want to share...',
                border: const OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: Text(isArabic ? 'إلغاء' : 'Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (controller.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isArabic ? 'يرجى كتابة نص الحالة' : 'Please write a story text'),
                      ),
                    );
                    return;
                  }

                  setState(() {
                    // ✅ إزالة الحالة السابقة للمستخدم
                    widget.stories.removeWhere((story) => story['isMine'] == true);
                    // ✅ إضافة الحالة الجديدة
                    widget.stories.insert(0, {
                      'id': DateTime.now().millisecondsSinceEpoch,
                      'name': isArabic ? 'أنت' : 'You',
                      'time': isArabic ? 'الآن' : 'Now',
                      'text': controller.text.trim(),
                      'viewed': false,
                      'isMine': true,
                    });
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isArabic ? '✅ تم نشر حالتك!' : '✅ Your story was published!'),
                      backgroundColor: Colors.green,
                    ),
                  );

                  Navigator.pop(dialogContext);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF18D3C3),
                  foregroundColor: Colors.white,
                ),
                child: Text(isArabic ? 'نشر' : 'Publish'),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // إضافة حالة صورة
  // ============================================================

  Future<void> _pickImageStory() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image != null) {
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      final isArabic = languageProvider.isArabic;
      final Uint8List bytes = await image.readAsBytes();
      if (!mounted) return;

      setState(() {
        // ✅ إزالة الحالة السابقة للمستخدم
        widget.stories.removeWhere((story) => story['isMine'] == true);
        // ✅ إضافة الحالة الجديدة. نحتفظ بالبايتات حتى تعمل المعاينة على Web.
        widget.stories.insert(0, {
          'id': DateTime.now().millisecondsSinceEpoch,
          'name': isArabic ? 'أنت' : 'You',
          'time': isArabic ? 'الآن' : 'Now',
          'text': isArabic ? '📷 حالة جديدة' : '📷 New story',
          'imagePath': image.path,
          'imageBytes': bytes,
          'viewed': false,
          'isMine': true,
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic ? '✅ تم نشر صورتك!' : '✅ Your photo was published!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _pickVideoStory() async {
    final picker = ImagePicker();
    final XFile? video = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 60),
    );

    if (video == null || !mounted) return;

    final isArabic = Provider.of<LanguageProvider>(context, listen: false).isArabic;
    final Uint8List videoBytes = await video.readAsBytes();
    if (!mounted) return;
    setState(() {
      widget.stories.removeWhere((story) => story['isMine'] == true);
      widget.stories.insert(0, {
        'id': DateTime.now().millisecondsSinceEpoch,
        'name': isArabic ? 'أنت' : 'You',
        'time': isArabic ? 'الآن' : 'Now',
        'text': isArabic ? '🎬 حالة فيديو' : '🎬 Video story',
        'videoPath': video.path,
        'videoBytes': videoBytes,
        'viewed': false,
        'isMine': true,
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isArabic ? '✅ تم نشر الفيديو!' : '✅ Your video was published!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              isArabic ? 'الحالات' : 'Stories',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: widget.stories.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _MyStoryCard(
                    onTap: _addMyStory,
                  );
                }
                final storyIndex = index - 1;
                final story = widget.stories[storyIndex];
                return _StoryCard(
                  story: story,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StoryViewScreen(
                          stories: widget.stories,
                          initialIndex: storyIndex,
                          onStoryViewed: (index) {
                            setState(() {
                              if (index < widget.stories.length) {
                                widget.stories[index]['viewed'] = true;
                              }
                            });
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// MY STORY CARD
// ============================================================

class _MyStoryCard extends StatelessWidget {
  final VoidCallback onTap;

  const _MyStoryCard({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Provider.of<LanguageProvider>(context).isArabic;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  child: const CircleAvatar(
                    backgroundColor: Color(0xFFDDF6F3),
                    child: Icon(
                      Icons.person_rounded,
                      color: Color(0xFF0B9F95),
                      size: 30,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Color(0xFF18D3C3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              isArabic ? 'حالتي' : 'My Story',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// STORY CARD
// ============================================================

class _StoryCard extends StatelessWidget {
  final Map<String, dynamic> story;
  final VoidCallback onTap;

  const _StoryCard({
    required this.story,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isViewed = story['viewed'] ?? false;
    final bool isMine = story['isMine'] ?? false;
    final isArabic = Provider.of<LanguageProvider>(context).isArabic;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isViewed || isMine
                    ? null
                    : const LinearGradient(
                        colors: [
                          Color(0xFFF7773D),
                          Color(0xFFE6436D),
                          Color(0xFF0B9F95),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                border: (isViewed || isMine)
                    ? Border.all(
                        color: Colors.grey.shade300,
                        width: 2,
                      )
                    : null,
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: CircleAvatar(
                  backgroundColor: Colors.grey.shade200,
                  child: Text(
                    story['name'][0],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0B9F95),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              story['name'],
              style: TextStyle(
                fontSize: 11,
                color: isViewed || isMine ? Colors.grey : Colors.black87,
                fontWeight: isViewed || isMine ? FontWeight.normal : FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// STORY TYPE BUTTON
// ============================================================

class _StoryTypeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _StoryTypeButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 30,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// STORY VIEW SCREEN
// ============================================================

class _StoryVideoPlayer extends StatefulWidget {
  final String path;
  final Uint8List? bytes;

  const _StoryVideoPlayer({
    required this.path,
    this.bytes,
  });

  @override
  State<_StoryVideoPlayer> createState() => _StoryVideoPlayerState();
}

class _StoryVideoPlayerState extends State<_StoryVideoPlayer> {
  VideoPlayerController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final path = widget.path;
      if (kIsWeb) {
        // Flutter Web cannot use VideoPlayerController.file. ImagePicker Web
        // normally returns a blob URL; use it directly. If a blob URL is not
        // available, fall back to a data URL built from the selected bytes.
        Uri? uri;
        if (path.startsWith('http://') ||
            path.startsWith('https://') ||
            path.startsWith('blob:') ||
            path.startsWith('data:')) {
          uri = Uri.tryParse(path);
        }
        if (uri == null && widget.bytes != null && widget.bytes!.isNotEmpty) {
          uri = Uri.dataFromBytes(widget.bytes!, mimeType: 'video/mp4');
        }
        if (uri == null) {
          throw Exception('No web video source available');
        }
        _controller = VideoPlayerController.networkUrl(uri);
      } else {
        _controller = VideoPlayerController.file(File(path));
      }

      await _controller!.initialize();
      await _controller!.setLooping(true);
      await _controller!.play();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return SizedBox(
        width: 300,
        height: 400,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.video_library_outlined, color: Colors.white, size: 52),
                const SizedBox(height: 12),
                Text(
                  kIsWeb
                      ? 'تعذر تشغيل الفيديو في المتصفح. حاول اختيار الفيديو مرة أخرى.'
                      : 'تعذر تشغيل الفيديو.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox(
        width: 300,
        height: 400,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return GestureDetector(
      onTap: () {
        if (controller.value.isPlaying) {
          controller.pause();
        } else {
          controller.play();
        }
        setState(() {});
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 300,
          height: 400,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryImagePreview extends StatelessWidget {
  final String? path;
  final Uint8List? bytes;
  final double width;
  final double height;

  const _StoryImagePreview({
    required this.path,
    required this.bytes,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    // Flutter Web لا يدعم Image.file/FileImage. البايتات هي المسار الآمن
    // للمعاينة الفورية بعد اختيار صورة من معرض الجهاز.
    if (bytes != null && bytes!.isNotEmpty) {
      return Image.memory(
        bytes!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }

    final value = path ?? '';
    final hasNetworkScheme = value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('blob:') ||
        value.startsWith('data:');

    if (kIsWeb && hasNetworkScheme) {
      return Image.network(
        value,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }

    if (!kIsWeb && value.isNotEmpty) {
      return Image.file(
        File(value),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }

    return _fallback();
  }

  Widget _fallback() => Container(
        width: width,
        height: height,
        color: Colors.grey.shade900,
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_not_supported_outlined,
          color: Colors.white54,
          size: 48,
        ),
      );
}

class StoryViewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> stories;
  final int initialIndex;
  final Function(int) onStoryViewed;

  const StoryViewScreen({
    super.key,
    required this.stories,
    required this.initialIndex,
    required this.onStoryViewed,
  });

  @override
  State<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onStoryViewed(_currentIndex);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ====================================================
          // STORY PAGES
          // ====================================================
          PageView.builder(
            controller: _pageController,
            itemCount: widget.stories.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
                widget.onStoryViewed(index);
              });
            },
            itemBuilder: (context, index) {
              final story = widget.stories[index];
              final bool isMine = story['isMine'] ?? false;
              final bool hasImage = story['imagePath'] != null;
              final bool hasVideo = story['videoPath'] != null;

              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: hasImage
                        ? [Colors.black, Colors.black]
                        : [
                            Colors.grey.shade800,
                            Colors.grey.shade900,
                          ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (hasImage)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: _StoryImagePreview(
                            path: story['imagePath']?.toString(),
                            bytes: story['imageBytes'] is Uint8List
                                ? story['imageBytes'] as Uint8List
                                : null,
                            width: 300,
                            height: 400,
                          ),
                        )
                      else if (hasVideo)
                        _StoryVideoPlayer(
                          path: story['videoPath'].toString(),
                          bytes: story['videoBytes'] is Uint8List
                              ? story['videoBytes'] as Uint8List
                              : null,
                        )
                      else
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: isMine
                                ? const Color(0xFF18D3C3)
                                : Colors.grey.shade700,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              story['name'][0],
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      Text(
                        story['name'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        story['time'],
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 30),
                      if (story['text'] != null && story['text'].isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.shade600,
                            ),
                          ),
                          child: Text(
                            story['text'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      if (isMine)
                        const SizedBox(height: 10),
                      if (isMine)
                        Text(
                          isArabic ? '👋 هذه حالتك' : '👋 This is your story',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),

          // ====================================================
          // LEFT TAP (للرجوع)
          // ====================================================
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 50,
            child: GestureDetector(
              onTap: () {
                if (_currentIndex > 0) {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),

          // ====================================================
          // RIGHT TAP (للتقدم)
          // ====================================================
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 50,
            child: GestureDetector(
              onTap: () {
                if (_currentIndex < widget.stories.length - 1) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),

          // ====================================================
          // PROGRESS BARS
          // ====================================================
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: Row(
              children: List.generate(
                widget.stories.length,
                (index) {
                  final isActive = index == _currentIndex;
                  final isViewed = widget.stories[index]['viewed'] ?? false;
                  return Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.white
                            : isViewed
                                ? Colors.grey
                                : Colors.grey.shade600,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // ====================================================
          // CLOSE BUTTON
          // ====================================================
          Positioned(
            top: 40,
            right: 16,
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.black26,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),

          // ====================================================
          // INFO
          // ====================================================
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                '${_currentIndex + 1} / ${widget.stories.length}',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}