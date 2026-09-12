import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import 'package:zameel/theme/app_theme.dart';
import '../../services_social.dart';

// ============================================================
// STORIES WIDGET (معدل بالكامل)
// ============================================================

class StoriesWidget extends StatefulWidget {
  final List<Map<String, dynamic>> stories;
  final bool friendsOnly;

  const StoriesWidget({
    super.key,
    this.stories = const <Map<String, dynamic>>[],
    this.friendsOnly = false,
  });

  @override
  State<StoriesWidget> createState() => _StoriesWidgetState();
}

String _storyOwnerKey(Map<String, dynamic> story) {
  if (story['isMine'] == true) return '__me__';
  final userId = story['user_id']?.toString().trim() ?? '';
  if (userId.isNotEmpty) return userId;
  final name = story['name']?.toString().trim() ?? '';
  return 'name:$name';
}

List<List<Map<String, dynamic>>> _groupStories(
  List<Map<String, dynamic>> stories,
) {
  final groups = <String, List<Map<String, dynamic>>>{};
  for (final story in stories) {
    groups.putIfAbsent(_storyOwnerKey(story), () => <Map<String, dynamic>>[]).add(story);
  }
  final result = groups.values.toList();
  final mineIndex = result.indexWhere((group) => group.any((story) => story['isMine'] == true));
  if (mineIndex > 0) {
    final mine = result.removeAt(mineIndex);
    result.insert(0, mine);
  }
  return result;
}

class _StoriesWidgetState extends State<StoriesWidget> {
  late final List<Map<String, dynamic>> _stories;
  bool _loading = true;
  String _storyAudience = 'public';

  @override
  void initState() {
    super.initState();
    _stories = widget.stories.map((story) => Map<String, dynamic>.from(story)).toList();
    _loadStories();
  }

  Future<void> _loadStories() async {
    if (!ZameelSocialService.signedIn) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final remote = await ZameelSocialService.loadStories(friendsOnly: widget.friendsOnly);
      final currentUserId = ZameelSocialService.uid;
      final normalized = remote.map((story) {
        final createdAt = DateTime.tryParse(story['created_at']?.toString() ?? '');
        final age = createdAt == null
            ? Duration.zero
            : DateTime.now().toUtc().difference(createdAt.toUtc());
        final type = story['media_type']?.toString() ?? 'text';
        final storyUser = story['users'] is Map
            ? Map<String, dynamic>.from(story['users'])
            : const <String, dynamic>{};
        final storyName = storyUser['name']?.toString().trim() ?? '';
        return <String, dynamic>{
          ...story,
          'name': storyName.isEmpty ? 'User' : storyName,
          'profileImage': storyUser['profile_image']?.toString(),
          'time_ar': age.inHours > 0 ? 'منذ ${age.inHours} س' : 'الآن',
          'time_en': age.inHours > 0 ? '${age.inHours}h ago' : 'Now',
          'text': story['caption']?.toString() ?? '',
          'imagePath': type == 'image' ? story['media_url']?.toString() : null,
          'videoPath': type == 'video' ? story['media_url']?.toString() : null,
          'viewed': false,
          'isMine': story['user_id'] == currentUserId,
        };
      }).toList();
      if (mounted) {
        setState(() {
          _stories
            ..clear()
            ..addAll(normalized);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _publishRemote({
    String? mediaUrl,
    required String mediaType,
    String caption = '',
  }) async {
    if (!ZameelSocialService.signedIn) return null;
    return ZameelSocialService.createStory(
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      caption: caption,
      audience: _storyAudience,
    );
  }

  String _audienceLabel(bool isArabic, String audience) {
    if (audience == 'college') return isArabic ? 'الكلية' : 'College';
    if (audience == 'department') return isArabic ? 'التخصص' : 'Major';
    return isArabic ? 'العامة' : 'Public';
  }

  void _addMyStory() {
    final isArabic = Provider.of<LanguageProvider>(context, listen: false).isArabic;
    var audience = _storyAudience;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) => Directionality(
            textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isArabic ? 'أضف حالة جديدة' : 'Add a new story',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      isArabic ? 'من يستطيع رؤية الحالة؟' : 'Who can see this story?',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          selected: audience == 'public',
                          avatar: const Icon(Icons.public_rounded, size: 18),
                          label: Text(isArabic ? 'العامة' : 'Public'),
                          onSelected: (_) => setSheetState(() => audience = 'public'),
                        ),
                        ChoiceChip(
                          selected: audience == 'college',
                          avatar: const Icon(Icons.account_balance_rounded, size: 18),
                          label: Text(isArabic ? 'الكلية' : 'College'),
                          onSelected: (_) => setSheetState(() => audience = 'college'),
                        ),
                        ChoiceChip(
                          selected: audience == 'department',
                          avatar: const Icon(Icons.school_rounded, size: 18),
                          label: Text(isArabic ? 'التخصص' : 'Major'),
                          onSelected: (_) => setSheetState(() => audience = 'department'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StoryTypeButton(
                          icon: Icons.text_fields_rounded,
                          label: isArabic ? 'نص' : 'Text',
                          color: AppTheme.primary,
                          onTap: () {
                            _storyAudience = audience;
                            Navigator.pop(sheetContext);
                            _showTextStoryDialog();
                          },
                        ),
                        _StoryTypeButton(
                          icon: Icons.image_rounded,
                          label: isArabic ? 'صورة' : 'Image',
                          color: Colors.green,
                          onTap: () {
                            _storyAudience = audience;
                            Navigator.pop(sheetContext);
                            _pickImageStory();
                          },
                        ),
                        _StoryTypeButton(
                          icon: Icons.videocam_rounded,
                          label: isArabic ? 'فيديو' : 'Video',
                          color: Colors.red,
                          onTap: () {
                            _storyAudience = audience;
                            Navigator.pop(sheetContext);
                            _pickVideoStory();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${isArabic ? 'الخصوصية' : 'Privacy'}: ${_audienceLabel(isArabic, audience)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.muted.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showTextStoryDialog() {
    final controller = TextEditingController();
    final isArabic = Provider.of<LanguageProvider>(context, listen: false).isArabic;

    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          title: Text(
            isArabic ? 'حالة جديدة' : 'New Story',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: controller,
                maxLines: 4,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: isArabic ? 'اكتب ما تريد مشاركته...' : 'Write what you want to share...',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.visibility_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text(_audienceLabel(isArabic, _storyAudience)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(isArabic ? 'إلغاء' : 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (controller.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isArabic ? 'يرجى كتابة نص الحالة' : 'Please write a story text')),
                  );
                  return;
                }
                final caption = controller.text.trim();
                final localStory = <String, dynamic>{
                  'id': 'local_${DateTime.now().microsecondsSinceEpoch}',
                  'user_id': ZameelSocialService.uid ?? '__local__',
                  'name': 'User',
                  'time_ar': 'الآن',
                  'time_en': 'Now',
                  'text': caption,
                  'media_type': 'text',
                  'audience': _storyAudience,
                  'viewed': false,
                  'isMine': true,
                };
                setState(() => _stories.insert(0, localStory));
                try {
                  final remoteId = await _publishRemote(mediaType: 'text', caption: caption);
                  if (remoteId != null) localStory['id'] = remoteId;
                } catch (_) {
                  _showMessage(isArabic ? 'نُشرت محليًا، وتعذرت المزامنة حاليًا' : 'Published locally; sync is currently unavailable');
                }
                if (!mounted || !dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isArabic ? '✅ تم نشر حالتك!' : '✅ Your story was published!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(isArabic ? 'نشر' : 'Publish'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageStory() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image == null) return;
    final isArabic = Provider.of<LanguageProvider>(context, listen: false).isArabic;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    final localStory = <String, dynamic>{
      'id': 'local_${DateTime.now().microsecondsSinceEpoch}',
      'user_id': ZameelSocialService.uid ?? '__local__',
      'name': 'User',
      'time_ar': 'الآن',
      'time_en': 'Now',
      'text': '',
      'media_type': 'image',
      'audience': _storyAudience,
      'imagePath': image.path,
      'imageBytes': bytes,
      'viewed': false,
      'isMine': true,
    };
    setState(() => _stories.insert(0, localStory));
    try {
      final url = await ZameelSocialService.uploadMediaBytes(bytes, filename: image.name, type: 'story');
      final remoteId = await _publishRemote(mediaUrl: url, mediaType: 'image');
      if (remoteId != null) localStory['id'] = remoteId;
    } catch (_) {
      _showMessage(isArabic ? 'نُشرت محليًا، وتعذرت المزامنة حاليًا' : 'Published locally; sync is currently unavailable');
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isArabic ? '✅ تم نشر صورتك!' : '✅ Your photo was published!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _pickVideoStory() async {
    final video = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 60),
    );
    if (video == null || !mounted) return;
    final isArabic = Provider.of<LanguageProvider>(context, listen: false).isArabic;
    final videoBytes = await video.readAsBytes();
    if (!mounted) return;
    final localStory = <String, dynamic>{
      'id': 'local_${DateTime.now().microsecondsSinceEpoch}',
      'user_id': ZameelSocialService.uid ?? '__local__',
      'name': 'User',
      'time_ar': 'الآن',
      'time_en': 'Now',
      'text': '',
      'media_type': 'video',
      'audience': _storyAudience,
      'videoPath': video.path,
      'videoBytes': videoBytes,
      'viewed': false,
      'isMine': true,
    };
    setState(() => _stories.insert(0, localStory));
    try {
      final url = await ZameelSocialService.uploadMediaBytes(videoBytes, filename: video.name, type: 'story_video');
      final remoteId = await _publishRemote(mediaUrl: url, mediaType: 'video');
      if (remoteId != null) localStory['id'] = remoteId;
    } catch (_) {
      _showMessage(isArabic ? 'نُشرت محليًا، وتعذرت المزامنة حاليًا' : 'Published locally; sync is currently unavailable');
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isArabic ? '✅ تم نشر الفيديو!' : '✅ Your video was published!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openStoryGroup(
    List<List<Map<String, dynamic>>> groups,
    List<Map<String, dynamic>> selectedGroup,
  ) {
    if (selectedGroup.isEmpty) {
      _addMyStory();
      return;
    }
    final ordered = groups.expand((group) => group).toList(growable: true);
    final selectedKey = _storyOwnerKey(selectedGroup.first);
    final initialIndex = ordered.indexWhere((story) => _storyOwnerKey(story) == selectedKey);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryViewScreen(
          stories: ordered,
          initialIndex: initialIndex < 0 ? 0 : initialIndex,
          onStoryViewed: (index) {
            if (index < 0 || index >= ordered.length || !mounted) return;
            setState(() => ordered[index]['viewed'] = true);
          },
          onStoryDeleted: (story) {
            if (!mounted) return;
            final id = story['id'];
            setState(() {
              _stories.removeWhere((item) => identical(item, story) || (id != null && item['id'] == id));
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Provider.of<LanguageProvider>(context).isArabic;
    final groups = _groupStories(_stories);
    final mineGroup = groups.firstWhere(
      (group) => group.any((story) => story['isMine'] == true),
      orElse: () => <Map<String, dynamic>>[],
    );
    final otherGroups = groups.where((group) => group.isNotEmpty && group.every((story) => story['isMine'] != true)).toList();

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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 92,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: otherGroups.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _StoryGroupCard(
                    stories: mineGroup,
                    isMine: true,
                    onTap: () => _openStoryGroup(groups, mineGroup),
                    onAdd: _addMyStory,
                  );
                }
                final group = otherGroups[index - 1];
                return _StoryGroupCard(
                  stories: group,
                  isMine: false,
                  onTap: () => _openStoryGroup(groups, group),
                );
              },
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }
}

class _StoryGroupCard extends StatelessWidget {
  final List<Map<String, dynamic>> stories;
  final bool isMine;
  final VoidCallback onTap;
  final VoidCallback? onAdd;

  const _StoryGroupCard({
    required this.stories,
    required this.isMine,
    required this.onTap,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Provider.of<LanguageProvider>(context).isArabic;
    final first = stories.isEmpty ? const <String, dynamic>{} : stories.first;
    final imageUrl = first['profileImage']?.toString() ?? '';
    final rawName = first['name']?.toString().trim() ?? '';
    final name = isMine
        ? (isArabic ? 'حالتي' : 'My Story')
        : (rawName.isEmpty ? (isArabic ? 'زميل' : 'Colleague') : rawName);
    final hasUnviewed = stories.any((story) => story['viewed'] != true);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: onTap,
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: !isMine && hasUnviewed
                        ? const LinearGradient(
                            colors: [AppTheme.warning, AppTheme.accent, AppTheme.primaryDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    border: !isMine && hasUnviewed
                        ? null
                        : Border.all(color: AppTheme.muted.shade300, width: 2),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: CircleAvatar(
                    backgroundColor: AppTheme.primaryLight,
                    backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                    child: imageUrl.isEmpty
                        ? Icon(
                            isMine ? Icons.person_rounded : Icons.person_outline_rounded,
                            color: AppTheme.primaryDark,
                            size: 30,
                          )
                        : null,
                  ),
                ),
              ),
              if (isMine && onAdd != null)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: GestureDetector(
                    onTap: onAdd,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.add_rounded, color: Colors.white, size: 15),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 72,
            child: Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: hasUnviewed && !isMine ? Colors.black87 : AppTheme.muted,
                fontWeight: hasUnviewed && !isMine ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
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
      final isNetworkSource = path.startsWith('http://') || path.startsWith('https://') || path.startsWith('blob:') || path.startsWith('data:');
      if (kIsWeb || isNetworkSource) {
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

    if (hasNetworkScheme) {
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
        color: AppTheme.muted.shade900,
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
  final ValueChanged<int> onStoryViewed;
  final ValueChanged<Map<String, dynamic>> onStoryDeleted;

  const StoryViewScreen({
    super.key,
    required this.stories,
    required this.initialIndex,
    required this.onStoryViewed,
    required this.onStoryDeleted,
  });

  @override
  State<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _deleting = false;
  final Set<String> _reactedStories = <String>{};
  final Map<String, int> _viewCounts = <String, int>{};
  final Map<String, int> _reactionCounts = <String, int>{};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.stories.isEmpty
        ? 0
        : widget.initialIndex < 0
            ? 0
            : widget.initialIndex >= widget.stories.length
                ? widget.stories.length - 1
                : widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.stories.isNotEmpty) {
        widget.onStoryViewed(_currentIndex);
        _recordCurrentView();
        _loadCurrentReactionState();
        _loadCurrentEngagementCounts();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _groupStart(int index) {
    if (widget.stories.isEmpty) return 0;
    final key = _storyOwnerKey(widget.stories[index]);
    var start = index;
    while (start > 0 && _storyOwnerKey(widget.stories[start - 1]) == key) {
      start--;
    }
    return start;
  }

  int _groupEnd(int index) {
    if (widget.stories.isEmpty) return 0;
    final key = _storyOwnerKey(widget.stories[index]);
    var end = index;
    while (end + 1 < widget.stories.length &&
        _storyOwnerKey(widget.stories[end + 1]) == key) {
      end++;
    }
    return end;
  }

  Future<void> _recordCurrentView() async {
    if (widget.stories.isEmpty) return;
    final story = widget.stories[_currentIndex];
    final id = story['id']?.toString() ?? '';
    if (id.isNotEmpty && story['isMine'] != true) {
      try { await ZameelSocialService.recordStoryView(id); } catch (_) {}
    }
  }

  Future<void> _loadCurrentReactionState() async {
    if (widget.stories.isEmpty) return;
    final story = widget.stories[_currentIndex];
    final id = story['id']?.toString() ?? '';
    if (id.isEmpty || story['isMine'] == true) return;
    try {
      final liked = await ZameelSocialService.isStoryReacted(id);
      if (!mounted) return;
      setState(() {
        if (liked) {
          _reactedStories.add(id);
        } else {
          _reactedStories.remove(id);
        }
      });
    } catch (_) {}
  }

  Future<void> _loadCurrentEngagementCounts() async {
    if (widget.stories.isEmpty) return;
    final id = widget.stories[_currentIndex]['id']?.toString() ?? '';
    if (id.isEmpty || id.startsWith('local_')) return;
    try {
      final counts = await ZameelSocialService.loadStoryEngagementCounts(id);
      if (!mounted) return;
      setState(() {
        _viewCounts[id] = counts['views'] ?? 0;
        _reactionCounts[id] = counts['reactions'] ?? 0;
      });
    } catch (_) {}
  }

  Future<void> _toggleCurrentReaction() async {
    if (widget.stories.isEmpty) return;
    final story = widget.stories[_currentIndex];
    final id = story['id']?.toString() ?? '';
    if (id.isEmpty || story['isMine'] == true) return;
    try {
      final liked = await ZameelSocialService.toggleStoryReaction(id);
      if (!mounted) return;
      setState(() { if (liked) { _reactedStories.add(id); } else { _reactedStories.remove(id); } });
      await _loadCurrentEngagementCounts();
    } catch (_) {}
  }

  Future<void> _showCurrentViewers(bool ar) async {
    if (widget.stories.isEmpty) return;
    final story = widget.stories[_currentIndex];
    final id = story['id']?.toString() ?? '';
    if (id.isEmpty || story['isMine'] != true) return;
    List<Map<String, dynamic>> viewers = [];
    List<Map<String, dynamic>> reactions = [];
    try {
      final result = await Future.wait([
        ZameelSocialService.loadStoryViewers(id),
        ZameelSocialService.loadStoryReactions(id),
      ]);
      viewers = result[0];
      reactions = result[1];
    } catch (_) {}
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.62,
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 2, 18, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          ar
                              ? '${viewers.length} مشاهدة • ${reactions.length} إعجاب'
                              : '${viewers.length} views • ${reactions.length} likes',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
                TabBar(
                  tabs: [
                    Tab(text: ar ? 'المشاهدون (${viewers.length})' : 'Viewers (${viewers.length})'),
                    Tab(text: ar ? 'الإعجابات (${reactions.length})' : 'Likes (${reactions.length})'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      viewers.isEmpty
                          ? Center(child: Text(ar ? 'لا توجد مشاهدات بعد' : 'No views yet'))
                          : ListView.builder(
                              itemCount: viewers.length,
                              itemBuilder: (_, i) {
                                final row = viewers[i];
                                final name = row['name']?.toString() ?? (ar ? 'زميل' : 'Colleague');
                                final image = row['profile_image']?.toString() ?? '';
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: image.isNotEmpty ? NetworkImage(image) : null,
                                    child: image.isEmpty ? const Icon(Icons.person) : null,
                                  ),
                                  title: Text(name),
                                  trailing: const Icon(Icons.visibility_rounded, size: 19),
                                );
                              },
                            ),
                      reactions.isEmpty
                          ? Center(child: Text(ar ? 'لا توجد إعجابات بعد' : 'No likes yet'))
                          : ListView.builder(
                              itemCount: reactions.length,
                              itemBuilder: (_, i) {
                                final row = reactions[i];
                                final name = row['name']?.toString() ?? (ar ? 'زميل' : 'Colleague');
                                final image = row['profile_image']?.toString() ?? '';
                                final reaction = row['reaction']?.toString() ?? '❤️';
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: image.isNotEmpty ? NetworkImage(image) : null,
                                    child: image.isEmpty ? const Icon(Icons.person) : null,
                                  ),
                                  title: Text(name),
                                  trailing: Text(reaction, style: const TextStyle(fontSize: 22)),
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _goNext() {
    if (_currentIndex < widget.stories.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _goPrevious() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
      );
    }
  }

  String _audienceText(bool isArabic, String? audience) {
    if (audience == 'college' || audience == 'faculty') {
      return isArabic ? 'الكلية' : 'College';
    }
    if (audience == 'department' || audience == 'group') {
      return isArabic ? 'التخصص' : 'Major';
    }
    if (audience == 'friends') return isArabic ? 'الزملاء' : 'Colleagues';
    if (audience == 'close_friends') {
      return isArabic ? 'المقربون' : 'Close friends';
    }
    return isArabic ? 'العامة' : 'Public';
  }

  Future<void> _deleteCurrent(bool isArabic) async {
    if (_deleting || widget.stories.isEmpty) return;
    final story = widget.stories[_currentIndex];
    if (story['isMine'] != true) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isArabic ? 'حذف الحالة؟' : 'Delete story?'),
        content: Text(
          isArabic
              ? 'سيتم حذف هذه الحالة نهائيًا.'
              : 'This story will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(isArabic ? 'حذف' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      final id = story['id'];
      if (id is String && !id.startsWith('local_')) {
        await ZameelSocialService.deleteStory(id);
      }
      widget.onStoryDeleted(story);
      widget.stories.removeAt(_currentIndex);
      if (!mounted) return;
      if (widget.stories.isEmpty) {
        Navigator.pop(context);
        return;
      }
      final nextIndex = _currentIndex >= widget.stories.length
          ? widget.stories.length - 1
          : _currentIndex;
      setState(() => _currentIndex = nextIndex);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) _pageController.jumpToPage(nextIndex);
        widget.onStoryViewed(nextIndex);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic ? 'تعذر حذف الحالة: $e' : 'Could not delete story: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Provider.of<LanguageProvider>(context).isArabic;
    if (widget.stories.isEmpty) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    final current = widget.stories[_currentIndex];
    final groupStart = _groupStart(_currentIndex);
    final groupEnd = _groupEnd(_currentIndex);
    final groupCount = groupEnd - groupStart + 1;
    final localIndex = _currentIndex - groupStart;
    final currentIsMine = current['isMine'] == true;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.stories.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              widget.onStoryViewed(index);
              _recordCurrentView();
              _loadCurrentReactionState();
              _loadCurrentEngagementCounts();
            },
            itemBuilder: (context, index) {
              final story = widget.stories[index];
              final isMine = story['isMine'] == true;
              final imagePath = story['imagePath']?.toString() ?? '';
              final videoPath = story['videoPath']?.toString() ?? '';
              final hasImage = imagePath.isNotEmpty || story['imageBytes'] is Uint8List;
              final hasVideo = videoPath.isNotEmpty || story['videoBytes'] is Uint8List;
              final displayName = isMine
                  ? (isArabic ? 'أنت' : 'You')
                  : ((story['name']?.toString().trim().isNotEmpty ?? false)
                      ? story['name'].toString()
                      : (isArabic ? 'زميل' : 'Colleague'));
              final time = isArabic
                  ? (story['time_ar'] ?? story['time'] ?? 'الآن').toString()
                  : (story['time_en'] ?? story['time'] ?? 'Now').toString();
              final text = story['text']?.toString() ?? '';

              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: (hasImage || hasVideo)
                        ? const [Colors.black, Colors.black]
                        : [AppTheme.muted.shade800, AppTheme.muted.shade900],
                  ),
                ),
                child: SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 90, 24, 80),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (hasImage)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: _StoryImagePreview(
                                path: imagePath,
                                bytes: story['imageBytes'] is Uint8List
                                    ? story['imageBytes'] as Uint8List
                                    : null,
                                width: 320,
                                height: 430,
                              ),
                            )
                          else if (hasVideo)
                            _StoryVideoPlayer(
                              path: videoPath,
                              bytes: story['videoBytes'] is Uint8List
                                  ? story['videoBytes'] as Uint8List
                                  : null,
                            )
                          else
                            Container(
                              constraints: const BoxConstraints(maxWidth: 560),
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withAlpha(65),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Text(
                                text,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  height: 1.55,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          const SizedBox(height: 18),
                          Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(time, style: const TextStyle(color: Colors.white70)),
                          if ((hasImage || hasVideo) && text.trim().isNotEmpty) ...[
                            const SizedBox(height: 18),
                            Container(
                              constraints: const BoxConstraints(maxWidth: 560),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                text,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _audienceText(isArabic, story['audience']?.toString()),
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned.fill(
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _goPrevious,
                    child: const SizedBox.expand(),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _goNext,
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 16,
            right: 70,
            child: Row(
              children: List.generate(groupCount, (index) {
                final absoluteIndex = groupStart + index;
                final viewed = widget.stories[absoluteIndex]['viewed'] == true;
                return Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: index == localIndex
                          ? Colors.white
                          : viewed
                              ? Colors.white54
                              : Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 22,
            right: 14,
            child: IconButton.filledTonal(
              onPressed: () => Navigator.pop(context),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black45,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
          if (currentIsMine)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 70,
              right: 14,
              child: IconButton.filledTonal(
                onPressed: _deleting ? null : () => _deleteCurrent(isArabic),
                tooltip: isArabic ? 'حذف الحالة' : 'Delete story',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black45,
                  foregroundColor: Colors.redAccent,
                ),
                icon: _deleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.delete_outline_rounded),
              ),
            ),
          Positioned(
            bottom: MediaQuery.paddingOf(context).bottom + 52,
            left: 18,
            right: 18,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (currentIsMine)
                  FilledButton.tonalIcon(
                    onPressed: () => _showCurrentViewers(isArabic),
                    icon: const Icon(Icons.visibility_rounded),
                    label: Text(isArabic
                        ? '${_viewCounts[current['id']?.toString()] ?? 0} مشاهدة • ${_reactionCounts[current['id']?.toString()] ?? 0} إعجاب'
                        : '${_viewCounts[current['id']?.toString()] ?? 0} views • ${_reactionCounts[current['id']?.toString()] ?? 0} likes'),
                  )
                else
                  FilledButton.tonalIcon(
                    onPressed: _toggleCurrentReaction,
                    style: FilledButton.styleFrom(backgroundColor: Colors.black45, foregroundColor: Colors.white),
                    icon: Icon(
                      _reactedStories.contains(current['id']?.toString() ?? '') ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: _reactedStories.contains(current['id']?.toString() ?? '') ? Colors.redAccent : Colors.white,
                    ),
                    label: Text('${_reactionCounts[current['id']?.toString()] ?? 0}'),
                  ),
              ],
            ),
          ),
          Positioned(
            bottom: MediaQuery.paddingOf(context).bottom + 18,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                '${localIndex + 1} / $groupCount',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
