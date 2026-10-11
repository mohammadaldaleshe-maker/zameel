import 'package:zameel/services/story_seen_store.dart';
import '../../services/story_order_service.dart';
import '../../services/chat_visibility_service.dart';
import 'story_media_editor.dart';
import 'package:zameel/theme/appearance_controller.dart';
import 'package:zameel/widgets/verified_name.dart';
import 'package:flutter/material.dart';
import '../../services/feature_control.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import 'package:zameel/theme/app_theme.dart';
import '../../services_social.dart';
import '../../services/media_cache_service.dart';
import '../../services/home_snapshot_service.dart';
import '../../services/video_source_service.dart';
import '../../widgets/cached_media_image.dart';
import '../../widgets/post_report_menu.dart';
import '../profile/profile_screen.dart';
import '../../platform/video_controller_factory.dart';
import '../../platform/local_image_widget.dart';

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

String _storyOwnerKey(Map<String, dynamic> story) => storyOwnerKey(story);
List<List<Map<String, dynamic>>> _groupStories(
        List<Map<String, dynamic>> stories) =>
    orderedStoryGroups(stories);

class _StoriesWidgetState extends State<StoriesWidget>
    with WidgetsBindingObserver {
  late final List<Map<String, dynamic>> _stories;
  bool _loading = true;
  String _storyAudience = 'public';
  Timer? _refreshTimer;
  bool _refreshing = false;
  bool _remoteShown = false;
  final Set<String> _seenIds = {};
  Future<void>? _seenLoaded;
  bool _viewerOpen = false;
  List<List<Map<String, dynamic>>>? _frozenGroups;
  Future<void> _loadSeen() => _seenLoaded ??= () async {
        final uid = ZameelSocialService.uid;
        if (uid != null) _seenIds.addAll(await StorySeenStore.load(uid));
      }();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _stories = widget.stories
        .map((story) => Map<String, dynamic>.from(story))
        .toList();
    _restoreStories();
    _loadStories();
    _refreshTimer =
        Timer.periodic(const Duration(minutes: 2), (_) => _loadStories());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshTimer?.cancel();
      _refreshTimer =
          Timer.periodic(const Duration(minutes: 2), (_) => _loadStories());
      _loadStories();
    } else {
      _refreshTimer?.cancel();
    }
  }

  Future<void> _restoreStories() async {
    final userId = ZameelSocialService.uid;
    if (userId == null || widget.friendsOnly) return;
    await _loadSeen();
    final cached = await HomeSnapshotService.read(userId, 'stories');
    for (final story in cached) {
      story['viewed'] = _seenIds.contains('${story['id']}');
    }
    if (!mounted ||
        _remoteShown ||
        ZameelSocialService.uid != userId ||
        cached.isEmpty) return;
    setState(() {
      _stories
        ..clear()
        ..addAll(cached);
      _loading = false;
    });
  }

  Future<void> _loadStories() async {
    if (_refreshing) return;
    if (!ZameelSocialService.signedIn) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    _refreshing = true;
    final userId = ZameelSocialService.uid;
    try {
      await _loadSeen();
      final remote = await ZameelSocialService.loadStories(
              friendsOnly: widget.friendsOnly, resolveMedia: false)
          .timeout(const Duration(seconds: 15));
      if (!mounted || ZameelSocialService.uid != userId) return;
      _remoteShown = true;
      final currentUserId = ZameelSocialService.uid;
      final normalized = remote.map((story) {
        final createdAt =
            DateTime.tryParse(story['created_at']?.toString() ?? '');
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
          'viewed': _seenIds.contains('${story['id']}'),
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
      if (userId != null && !widget.friendsOnly) {
        unawaited(HomeSnapshotService.save(userId, 'stories', normalized));
      }
      // Do not pre-download every story just because the tray refreshed.
      // Circle previews remain lightweight; the full viewer caches only the
      // current item and at most the next one when the user actually opens it.
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    } finally {
      _refreshing = false;
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
    final isArabic =
        Provider.of<LanguageProvider>(context, listen: false).isArabic;
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
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      isArabic
                          ? 'من يستطيع رؤية الحالة؟'
                          : 'Who can see this story?',
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
                          onSelected: (_) =>
                              setSheetState(() => audience = 'public'),
                        ),
                        ChoiceChip(
                          selected: audience == 'college',
                          avatar: const Icon(Icons.account_balance_rounded,
                              size: 18),
                          label: Text(isArabic ? 'الكلية' : 'College'),
                          onSelected: (_) =>
                              setSheetState(() => audience = 'college'),
                        ),
                        ChoiceChip(
                          selected: audience == 'department',
                          avatar: const Icon(Icons.school_rounded, size: 18),
                          label: Text(isArabic ? 'التخصص' : 'Major'),
                          onSelected: (_) =>
                              setSheetState(() => audience = 'department'),
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
                      style: TextStyle(
                          color: AppTheme.adaptiveMuted.shade600, fontSize: 12),
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
    final isArabic =
        Provider.of<LanguageProvider>(context, listen: false).isArabic;

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
                  hintText: isArabic
                      ? 'اكتب ما تريد مشاركته...'
                      : 'Write what you want to share...',
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
                    SnackBar(
                        content: Text(isArabic
                            ? 'يرجى كتابة نص الحالة'
                            : 'Please write a story text')),
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
                  final remoteId =
                      await _publishRemote(mediaType: 'text', caption: caption);
                  if (remoteId != null) localStory['id'] = remoteId;
                } catch (error) {
                  if (FeatureControl.isSuspendedError(error)) {
                    if (mounted) setState(() => _stories.remove(localStory));
                    _showMessage(FeatureControl.suspendedMessage);
                    return;
                  }
                  _showMessage(isArabic
                      ? 'نُشرت محليًا، وتعذرت المزامنة حاليًا'
                      : 'Published locally; sync is currently unavailable');
                }
                if (!mounted || !dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isArabic
                        ? '✅ تم نشر حالتك!'
                        : '✅ Your story was published!'),
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

  Future<void> _pickImageStory() => _pickStoryMedia(false);
  Future<void> _pickVideoStory() => _pickStoryMedia(true);
  Future<void> _pickStoryMedia(bool video) async {
    final source = await _storyMediaSource(video: video);
    if (source == null) return;
    try {
      final file = video
          ? await ImagePicker().pickVideo(
              source: source, maxDuration: const Duration(seconds: 45))
          : await ImagePicker()
              .pickImage(source: source, imageQuality: 80, maxWidth: 1920);
      if (file == null || !mounted) return;
      final draft = await Navigator.push<StoryMediaDraft>(
          context,
          MaterialPageRoute(
              builder: (_) => StoryMediaEditor(
                  file: file, video: video, audience: _storyAudience)));
      if (draft == null || !mounted) return;
      final id = await ZameelSocialService.createStoryFile(
          file: draft.file, mediaType: draft.type, audience: draft.audience);
      if (id == null) throw StateError('story_not_saved');
      await _loadStories();
      if (mounted) _showMessage('تم نشر الحالة');
    } catch (_) {
      if (mounted)
        _showMessage(
            'تعذر نشر الحالة. تحقق من الأذونات والاتصال وحاول مرة أخرى.');
    }
  }

  Future<ImageSource?> _storyMediaSource({required bool video}) =>
      showModalBottomSheet<ImageSource>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
            child: Wrap(children: [
          ListTile(
            leading: Icon(
                video ? Icons.videocam_rounded : Icons.photo_camera_rounded),
            title: Text(video ? 'التسجيل من الكاميرا' : 'التصوير من الكاميرا'),
            subtitle: video ? const Text('بحد أقصى 45 ثانية') : null,
            onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded),
            title: const Text('اختيار من الهاتف'),
            onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
          ),
        ])),
      );

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openStoryGroup(
    List<List<Map<String, dynamic>>> groups,
    List<Map<String, dynamic>> selectedGroup,
  ) async {
    if (selectedGroup.isEmpty) {
      _addMyStory();
      return;
    }
    final ordered = groups.expand((group) => group).toList(growable: true);
    final selectedKey = _storyOwnerKey(selectedGroup.first);
    final unseenIndex = ordered.indexWhere((story) =>
        _storyOwnerKey(story) == selectedKey && story['viewed'] != true);
    final initialIndex = unseenIndex >= 0
        ? unseenIndex
        : ordered.indexWhere((story) => _storyOwnerKey(story) == selectedKey);
    _viewerOpen = true;
    _frozenGroups = groups;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryViewScreen(
          stories: ordered,
          initialIndex: initialIndex < 0 ? 0 : initialIndex,
          onStoryViewed: (index) {
            if (index < 0 || index >= ordered.length || !mounted) return;
            setState(() => ordered[index]['viewed'] = true);
            final id = ordered[index]['id']?.toString();
            final uid = ZameelSocialService.uid;
            if (id != null && uid != null) {
              _seenIds.add(id);
              unawaited(StorySeenStore.save(uid, _seenIds));
            }
          },
          onStoryDeleted: (story) {
            if (!mounted) return;
            final id = story['id'];
            setState(() {
              _stories.removeWhere((item) =>
                  identical(item, story) || (id != null && item['id'] == id));
            });
          },
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _viewerOpen = false;
      _frozenGroups = null;
      for (final story in _stories) {
        story['viewed'] =
            _seenIds.contains('${story['id']}') || story['viewed'] == true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    AppearanceScope.observe(context);
    final isArabic = Provider.of<LanguageProvider>(context).isArabic;
    final groups = _viewerOpen
        ? (_frozenGroups ?? _groupStories(_stories))
        : _groupStories(_stories);
    final mineGroup = groups.firstWhere(
      (group) => group.any((story) => story['isMine'] == true),
      orElse: () => <Map<String, dynamic>>[],
    );
    final otherGroups = groups
        .where((group) =>
            group.isNotEmpty && group.every((story) => story['isMine'] != true))
        .toList();

    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
    AppearanceScope.observe(context);
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
                            colors: [
                              AppTheme.warning,
                              AppTheme.accent,
                              AppTheme.primaryDark
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    border: !isMine && hasUnviewed
                        ? null
                        : Border.all(
                            color: AppTheme.adaptiveMuted.shade300, width: 2),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: ClipOval(
                    child: stories.isNotEmpty
                        ? _StoryCirclePreview(
                            key: ValueKey(first['id']), story: first)
                        : ColoredBox(
                            color: AppTheme.primaryLight,
                            child: Center(
                              child: imageUrl.isNotEmpty
                                  ? Image.network(imageUrl,
                                      width: 58, height: 58, fit: BoxFit.cover)
                                  : Icon(
                                      isMine
                                          ? Icons.person_rounded
                                          : Icons.person_outline_rounded,
                                      color: AppTheme.primaryDark,
                                      size: 30),
                            ),
                          ),
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
                      child: const Icon(Icons.add_rounded,
                          color: Colors.white, size: 15),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 72,
            child: VerifiedName(
                userId: first['user_id']?.toString(),
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: hasUnviewed && !isMine
                        ? AppTheme.adaptiveText
                        : AppTheme.muted,
                    fontWeight: hasUnviewed && !isMine
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                )),
          ),
        ],
      ),
    );
  }
}

class _StoryCirclePreview extends StatefulWidget {
  final Map<String, dynamic> story;
  const _StoryCirclePreview({super.key, required this.story});

  @override
  State<_StoryCirclePreview> createState() => _StoryCirclePreviewState();
}

class _StoryCirclePreviewState extends State<_StoryCirclePreview> {
  VideoPlayerController? _controller;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final video = widget.story['videoPath']?.toString() ?? '';
    if (video.isNotEmpty) _prepareVideo(video).catchError((Object _) {});
  }

  Future<void> _prepareVideo(String url) async {
    final controller = await VideoSourceService.controller(url);
    if (!mounted) {
      await controller.dispose();
      return;
    }
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted || _controller != controller) return;
      await controller.setVolume(0);
      await controller.seekTo(Duration.zero);
      await controller.play();
      if (!mounted || _controller != controller) return;
      _timer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted && _controller == controller) controller.pause();
      });
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppearanceScope.observe(context);
    final image = widget.story['imagePath']?.toString() ?? '';
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller)),
        ),
      );
    }
    if (image.isNotEmpty) {
      return SizedBox(
          width: 58,
          height: 58,
          child: CachedMediaImage(
            url: image,
            fit: BoxFit.cover,
            cacheWidth: 180,
            fallback: const Icon(Icons.image_outlined),
          ));
    }
    final text = widget.story['text']?.toString() ?? '';
    return ColoredBox(
      color: AppTheme.primary,
      child: Center(
          child: Padding(
              padding: const EdgeInsets.all(5),
              child: Text(text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold)))),
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
    AppearanceScope.observe(context);
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

class StoryVideoPlayer extends StatefulWidget {
  final String path;
  final bool pausedForReport;
  final bool active;
  final Uint8List? bytes;

  const StoryVideoPlayer({
    super.key,
    required this.path,
    this.pausedForReport = false,
    this.active = true,
    this.bytes,
  });

  @override
  State<StoryVideoPlayer> createState() => StoryVideoPlayerState();
}

class StoryVideoPlayerState extends State<StoryVideoPlayer>
    with WidgetsBindingObserver {
  bool _userPaused = false;
  bool _foreground = true;
  int _generation = 0;
  Future<void> _playbackOperations = Future.value();
  bool get _shouldPlay =>
      mounted &&
      widget.active &&
      !widget.pausedForReport &&
      _foreground &&
      !_userPaused;
  void _applyPlayback() {
    _playbackOperations =
        _playbackOperations.catchError((Object _) {}).then((_) async {
      final c = _controller;
      if (c == null || !c.value.isInitialized) return;
      if (_shouldPlay) {
        await c.setVolume(1);
        if (_shouldPlay && identical(c, _controller)) await c.play();
      } else {
        await c.setVolume(0);
        await c.pause();
      }
    }).catchError((Object e) {
      debugPrint('Story playback: $e');
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _applyPlayback();
  }

  VideoPlayerController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _initialize();
  }

  @override
  void didUpdateWidget(covariant StoryVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path || oldWidget.bytes != widget.bytes) {
      final previous = _controller;
      _controller = null;
      _userPaused = false;
      if (previous != null) unawaited(_stopAndDispose(previous));
      _initialize();
    } else {
      _applyPlayback();
    }
  }

  Future<void> _stopAndDispose(VideoPlayerController controller) async {
    try {
      await controller.setVolume(0);
      await controller.pause();
    } catch (e) {
      debugPrint('Story stopping: $e');
    } finally {
      await controller.dispose();
    }
  }

  Future<void> _initialize() async {
    final generation = ++_generation;
    VideoPlayerController? candidate;
    try {
      final path = widget.path;
      if (path.startsWith('http://') ||
          path.startsWith('https://') ||
          path.startsWith('zameel-private://')) {
        candidate = await VideoSourceService.controller(path);
      } else if (kIsWeb ||
          path.startsWith('blob:') ||
          path.startsWith('data:')) {
        final validUri = path.startsWith('blob:') ||
            path.startsWith('data:') ||
            path.startsWith('https://') ||
            path.startsWith('http://');
        final uri = validUri
            ? Uri.tryParse(path)
            : (widget.bytes == null
                ? null
                : Uri.dataFromBytes(widget.bytes!, mimeType: 'video/mp4'));
        if (uri == null) throw StateError('No video source');
        candidate = VideoPlayerController.networkUrl(uri);
      } else {
        candidate = videoControllerFromLocalPath(path);
      }
      if (!mounted || generation != _generation) {
        await candidate.dispose();
        return;
      }
      await candidate.initialize();
      await candidate.setLooping(true);
      if (!mounted || generation != _generation) {
        await candidate.dispose();
        return;
      }
      _controller = candidate;
      _applyPlayback();
      setState(() => _error = null);
    } catch (e) {
      if (candidate != null && !identical(candidate, _controller))
        await candidate.dispose();
      if (mounted && generation == _generation)
        setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ++_generation;
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      unawaited(_stopAndDispose(controller));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppearanceScope.observe(context);
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
                const Icon(Icons.video_library_outlined,
                    color: Colors.white, size: 52),
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
        _userPaused = !_userPaused;
        _applyPlayback();
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
    AppearanceScope.observe(context);
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
        value.startsWith('zameel-private://');
    if (hasNetworkScheme) {
      return SizedBox(
          width: width,
          height: height,
          child: CachedMediaImage(
            url: value,
            fit: BoxFit.cover,
            fallback: _fallback(),
          ));
    }
    if (value.startsWith('blob:') || value.startsWith('data:')) {
      return Image.network(value,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback());
    }

    if (!kIsWeb && value.isNotEmpty) {
      return localImageFromPath(
        value,
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
        color: const Color(0xFF161B29),
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

class _StoryViewScreenState extends State<StoryViewScreen>
    with WidgetsBindingObserver, RouteAware {
  ModalRoute<dynamic>? _playbackRoute;
  bool _routeVisible = true;
  bool _foreground = true;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _playbackRoute) {
      chatRouteObserver.unsubscribe(this);
      _playbackRoute = route;
      if (route != null) chatRouteObserver.subscribe(this, route);
    }
    _routeVisible = route?.isCurrent == true;
  }

  @override
  void didPush() {
    _routeVisible = true;
  }

  @override
  void didPushNext() {
    if (mounted) setState(() => _routeVisible = false);
  }

  @override
  void didPopNext() {
    if (mounted) setState(() => _routeVisible = true);
  }

  @override
  void didPop() {
    if (mounted) setState(() => _routeVisible = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted)
      setState(() => _foreground = state == AppLifecycleState.resumed);
  }

  late final PageController _pageController;
  late int _currentIndex;
  bool _deleting = false;
  final Set<String> _reactedStories = <String>{};
  final Map<String, int> _viewCounts = <String, int>{};
  final Map<String, int> _reactionCounts = <String, int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = widget.stories.isEmpty
        ? 0
        : widget.initialIndex < 0
            ? 0
            : widget.initialIndex >= widget.stories.length
                ? widget.stories.length - 1
                : widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _prefetchAround(_currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.stories.isNotEmpty) {
        widget.onStoryViewed(_currentIndex);
        _recordCurrentView();
        _loadCurrentReactionState();
        _loadCurrentEngagementCounts();
      }
    });
  }

  void _prefetchAround(int index) {
    // The current story fetches itself. Cache only the next story so swiping
    // stays smooth without eagerly downloading several videos the user may
    // never watch (important for Supabase cached-egress usage).
    final next = index + 1;
    if (next < 0 || next >= widget.stories.length) return;
    final story = widget.stories[next];
    for (final key in const ['imagePath']) {
      final url = story[key]?.toString() ?? '';
      if (url.startsWith('http') || url.startsWith('zameel-private://')) {
        unawaited(MediaCacheService.prefetch(<String>[url], limit: 1));
        return;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    chatRouteObserver.unsubscribe(this);
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
      try {
        await ZameelSocialService.recordStoryView(id);
      } catch (_) {}
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
      setState(() {
        if (liked) {
          _reactedStories.add(id);
        } else {
          _reactedStories.remove(id);
        }
      });
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
                    Tab(
                        text: ar
                            ? 'المشاهدون (${viewers.length})'
                            : 'Viewers (${viewers.length})'),
                    Tab(
                        text: ar
                            ? 'الإعجابات (${reactions.length})'
                            : 'Likes (${reactions.length})'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      viewers.isEmpty
                          ? Center(
                              child: Text(
                                  ar ? 'لا توجد مشاهدات بعد' : 'No views yet'))
                          : ListView.builder(
                              itemCount: viewers.length,
                              itemBuilder: (_, i) {
                                final row = viewers[i];
                                final name = row['name']?.toString() ??
                                    (ar ? 'زميل' : 'Colleague');
                                final image =
                                    row['profile_image']?.toString() ?? '';
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: image.isNotEmpty
                                        ? NetworkImage(image)
                                        : null,
                                    child: image.isEmpty
                                        ? const Icon(Icons.person)
                                        : null,
                                  ),
                                  title: VerifiedName(
                                      userId: row['user_id']?.toString(),
                                      child: Text(name)),
                                  trailing: const Icon(Icons.visibility_rounded,
                                      size: 19),
                                );
                              },
                            ),
                      reactions.isEmpty
                          ? Center(
                              child: Text(
                                  ar ? 'لا توجد إعجابات بعد' : 'No likes yet'))
                          : ListView.builder(
                              itemCount: reactions.length,
                              itemBuilder: (_, i) {
                                final row = reactions[i];
                                final name = row['name']?.toString() ??
                                    (ar ? 'زميل' : 'Colleague');
                                final image =
                                    row['profile_image']?.toString() ?? '';
                                final reaction =
                                    row['reaction']?.toString() ?? '❤️';
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: image.isNotEmpty
                                        ? NetworkImage(image)
                                        : null,
                                    child: image.isEmpty
                                        ? const Icon(Icons.person)
                                        : null,
                                  ),
                                  title: VerifiedName(
                                      userId: row['user_id']?.toString(),
                                      child: Text(name)),
                                  trailing: Text(reaction,
                                      style: const TextStyle(fontSize: 22)),
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

  bool _reporting = false;

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
              FeatureControl.errorMessage(
                  e, isArabic ? 'تعذر حذف الحالة' : 'Could not delete story'),
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
    AppearanceScope.observe(context);
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
              _prefetchAround(index);
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
              final hasImage =
                  imagePath.isNotEmpty || story['imageBytes'] is Uint8List;
              final hasVideo =
                  videoPath.isNotEmpty || story['videoBytes'] is Uint8List;
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
                        : [const Color(0xFF252B3A), const Color(0xFF161B29)],
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
                            StoryVideoPlayer(
                              key: ValueKey(
                                  'story-video-${story['id'] ?? index}'),
                              path: videoPath,
                              active: index == _currentIndex &&
                                  _routeVisible &&
                                  _foreground,
                              pausedForReport: _reporting,
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
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  height: 1.55,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          const SizedBox(height: 18),
                          VerifiedName(
                              userId: story['user_id']?.toString(),
                              child: Text(
                                displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              )),
                          const SizedBox(height: 6),
                          Text(time,
                              style: const TextStyle(color: Colors.white70)),
                          if ((hasImage || hasVideo) &&
                              text.trim().isNotEmpty) ...[
                            const SizedBox(height: 18),
                            Container(
                              constraints: const BoxConstraints(maxWidth: 560),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                text,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.white, fontSize: 16),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _audienceText(
                                  isArabic, story['audience']?.toString()),
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
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
            top: MediaQuery.paddingOf(context).top + 25,
            left: 16,
            right: 70,
            child: InkWell(
              onTap: current['user_id'] == null
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ProfileScreen(
                              userId: current['user_id'].toString()))),
              child: Row(children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: Colors.white24,
                  backgroundImage:
                      (current['profileImage']?.toString() ?? '').isNotEmpty
                          ? NetworkImage(current['profileImage'].toString())
                          : null,
                  child: (current['profileImage']?.toString() ?? '').isEmpty
                      ? const Icon(Icons.person, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 9),
                Expanded(
                    child: VerifiedName(
                        userId: current['user_id']?.toString(),
                        child: Text(
                            currentIsMine
                                ? (isArabic ? 'أنت' : 'You')
                                : (current['name']?.toString() ??
                                    (isArabic ? 'زميل' : 'Colleague')),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800)))),
              ]),
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
          if (!currentIsMine)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 70,
              right: 14,
              child: MediaReportButton(
                contentId: current['id']?.toString() ?? '',
                authorId: current['user_id']?.toString(),
                contentType: 'story',
                ar: isArabic,
                onReportOpened: () {
                  if (mounted) setState(() => _reporting = true);
                },
                onReportClosed: () {
                  if (mounted) setState(() => _reporting = false);
                },
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
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
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
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.black45,
                        foregroundColor: Colors.white),
                    icon: Icon(
                      _reactedStories.contains(current['id']?.toString() ?? '')
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: _reactedStories
                              .contains(current['id']?.toString() ?? '')
                          ? Colors.redAccent
                          : Colors.white,
                    ),
                    label: Text(
                        '${_reactionCounts[current['id']?.toString()] ?? 0}'),
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
