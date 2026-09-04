import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'dart:typed_data';
import '../../services_social.dart';
import 'zameel_camera_capture_screen.dart';

class ZameelSocialStudio extends StatefulWidget {
  final bool isArabic;
  const ZameelSocialStudio({super.key, required this.isArabic});

  @override
  State<ZameelSocialStudio> createState() => _ZameelSocialStudioState();
}

class _ZameelSocialStudioState extends State<ZameelSocialStudio>
    with SingleTickerProviderStateMixin {
  late final TabController tabs;
  final picker = ImagePicker();
  final note = TextEditingController();

  String? storyPath;
  String? clipPath;
  Uint8List? storyBytes;
  Uint8List? clipBytes;
  bool closeFriends = false;
  bool replies = true;
  bool comments = true;
  String clipAudience = 'public';
  bool syncing = false;

  List<Map<String, dynamic>> storiesData = [];
  List<Map<String, dynamic>> clipsData = [];
  final Set<String> likedClips = <String>{};

  final List<String> highlights = <String>['يومي', 'الجامعة', 'ذكريات'];
  final List<String> friends = <String>['أحمد', 'سارة', 'محمد'];

  bool get ar => widget.isArabic;

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 4, vsync: this);
    load();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      note.text = prefs.getString('zameel_note') ?? '';
      storyPath = prefs.getString('zameel_story_path');
      clipPath = prefs.getString('zameel_clip_path');
      closeFriends = prefs.getBool('zameel_close_friends_only') ?? false;
      replies = prefs.getBool('zameel_story_replies') ?? true;
      comments = prefs.getBool('zameel_clip_comments') ?? true;
      clipAudience = prefs.getString('zameel_clip_audience') ?? 'public';
    });
    if (ZameelSocialService.signedIn) {
      await refreshRemote();
    }
  }

  Future<void> refreshRemote() async {
    if (!mounted) return;
    setState(() => syncing = true);
    try {
      final stories = await ZameelSocialService.loadStories();
      final clips = await ZameelSocialService.loadClips();
      if (!mounted) return;
      setState(() {
        storiesData = stories;
        clipsData = clips;
      });
    } catch (_) {
      // Keep local content available if Supabase is temporarily unavailable.
    } finally {
      if (mounted) setState(() => syncing = false);
    }
  }

  @override
  void dispose() {
    tabs.dispose();
    note.dispose();
    super.dispose();
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> saveNote() async {
    final text = note.text.trim();
    if (text.isEmpty) {
      showMessage(ar ? 'اكتب ملاحظة أولاً' : 'Write a note first');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('zameel_note', text);

    if (ZameelSocialService.signedIn) {
      try {
        await ZameelSocialService.upsertNote(
          text,
          audience: closeFriends ? 'close_friends' : 'friends',
        );
      } catch (_) {
        showMessage(ar ? 'تم حفظها محلياً' : 'Saved locally');
        return;
      }
    }

    showMessage(ar ? 'تم نشر الملاحظة لمدة 24 ساعة' : 'Note published for 24 hours');
  }

  Future<void> pickStory(bool video) async {
    final XFile? file = video
        ? await picker.pickVideo(
            source: ImageSource.gallery,
            maxDuration: const Duration(seconds: 45),
          )
        : await picker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 88,
          );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('zameel_story_path', file.path);

    if (ZameelSocialService.signedIn) {
      try {
        final String? url = await ZameelSocialService.uploadMediaBytes(
          bytes,
          filename: file.name,
          type: video ? 'story_video' : 'story',
        );
        if (url != null) {
          storyPath = url;
          await ZameelSocialService.createStory(
            mediaUrl: url,
            mediaType: video ? 'video' : 'image',
            audience: closeFriends ? 'close_friends' : 'friends',
          );
        }
      } catch (e) {
        if (mounted) showMessage(ar ? 'تعذر نشر الحالة على الخادم: $e' : 'Story upload failed: $e');
      }
    }

    if (!mounted) return;
    setState(() {
      storyPath = storyPath ?? file.path;
      storyBytes = bytes;
    });
    showMessage(ar ? 'تم نشر الحالة' : 'Story published');
    if (ZameelSocialService.signedIn) await refreshRemote();
  }

  Future<void> pickClip({bool camera = false}) async {
    final XFile? file = camera
        ? await Navigator.push<XFile>(context, MaterialPageRoute(builder: (_) => const ZameelCameraCaptureScreen()))
        : await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 120));
    if (file == null) return;

    final bytes = await file.readAsBytes();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('zameel_clip_path', file.path);

    bool uploaded = false;
    if (ZameelSocialService.signedIn) {
      try {
        final uploadedClip = await ZameelSocialService.createClipBytes(
          bytes: bytes,
          filename: file.name,
          durationSeconds: 120,
          audience: clipAudience,
        );
        // Use the remote URL for the preview when available; this works on Flutter Web.
        if (uploadedClip != null) {
          uploaded = true;
          final remote = await ZameelSocialService.loadClips();
          final mine = remote.cast<Map<String, dynamic>>().where((row) => row['id'] == uploadedClip).toList();
          if (mine.isNotEmpty && mine.first['video_url'] is String) {
            clipPath = mine.first['video_url'] as String;
          }
        }
      } catch (e) {
        if (mounted) showMessage(ar ? 'تعذر نشر الـClip: $e' : 'Clip upload failed: $e');
      }
    }

    if (!mounted) return;
    setState(() {
      clipPath = clipPath ?? file.path;
      clipBytes = bytes;
    });
    if (uploaded || !ZameelSocialService.signedIn) {
      showMessage(ar ? 'تم نشر الـClip بنجاح' : 'Clip published successfully');
      if (ZameelSocialService.signedIn) await refreshRemote();
    } else {
      showMessage(ar ? 'لم يتم نشر الـClip. تحقق من اتصال الخادم.' : 'Clip was not published. Check the server connection.');
    }
  }

  Future<void> creator() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              runSpacing: 8,
              children: <Widget>[
                Text(
                  ar ? 'إنشاء محتوى' : 'Create content',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                _createTile(
                  Icons.image,
                  ar ? 'منشور صور' : 'Photo post',
                  () => pickStory(false),
                  sheetContext,
                ),
                _createTile(
                  Icons.movie_creation,
                  ar ? 'Clip / Reel جامعي' : 'Campus Clip / Reel',
                  pickClip,
                  sheetContext,
                ),
                _createTile(
                  Icons.auto_stories,
                  ar ? 'حالة / Story' : 'Story',
                  () => pickStory(false),
                  sheetContext,
                ),
                _createTile(
                  Icons.videocam,
                  ar ? 'حالة فيديو' : 'Video Story',
                  () => pickStory(true),
                  sheetContext,
                ),
                _createTile(
                  Icons.text_fields,
                  ar ? 'ملاحظة سريعة' : 'Quick Note',
                  () {
                    Navigator.pop(sheetContext);
                    tabs.animateTo(2);
                  },
                  sheetContext,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _createTile(
    IconData icon,
    String text,
    VoidCallback action,
    BuildContext sheetContext,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(text),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.pop(sheetContext);
        action();
      },
    );
  }

  Widget _sectionTitle(String heading, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          heading,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _card(IconData icon, String title, Widget child) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(top: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  bool _looksLikeVideo(String path) {
    final extension = path.split('.').last.toLowerCase();
    return <String>['mp4', 'mov', 'm4v', 'webm', 'mkv'].contains(extension);
  }

  Widget _preview(String? path, String title) {
    if (path == null || path.isEmpty) return const SizedBox.shrink();

    final bool isVideo = _looksLikeVideo(path);
    final bool isStory = title.contains('حالة') || title.toLowerCase().contains('story');
    final Uint8List? bytes = isStory ? storyBytes : clipBytes;
    final Widget child;

    if (isVideo) {
      child = VideoFilePreview(path: path);
    } else if (bytes != null && bytes.isNotEmpty) {
      // XFile bytes are the portable Flutter Web/mobile representation.
      child = Image.memory(
        bytes,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _mediaError(),
      );
    } else if (path.startsWith('http://') || path.startsWith('https://') || path.startsWith('blob:')) {
      child = Image.network(
        path,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _mediaError(),
      );
    } else {
      child = _mediaError();
    }

    return _card(
      Icons.preview_rounded,
      title,
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: child,
      ),
    );
  }

  Widget _mediaError() {
    return Container(
      height: 180,
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported_outlined, size: 50),
    );
  }

  Widget stories() {
    final List<String> names = <String>[
      ar ? 'قصتي' : 'Your story',
      'أصدقاء',
      'الجامعة',
      'دفعتنا',
      'النادي',
    ];
    final List<IconData> icons = <IconData>[
      Icons.add_a_photo,
      Icons.people,
      Icons.school,
      Icons.groups,
      Icons.sports_soccer,
    ];

    return RefreshIndicator(
      onRefresh: refreshRemote,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _sectionTitle(
            ar ? 'Stories زميل' : 'Zameel Stories',
            ar ? 'لحظات سريعة للأصدقاء والجامعة' : 'Quick moments for friends and campus',
          ),
          if (syncing) const LinearProgressIndicator(),
          const SizedBox(height: 14),
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: names.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, index) {
                return GestureDetector(
                  onTap: index == 0
                      ? () => pickStory(false)
                      : () => showMessage(
                            ar
                                ? 'ستظهر قصص الجامعة هنا'
                                : 'Campus stories will appear here',
                          ),
                  child: Column(
                    children: <Widget>[
                      Container(
                        width: 74,
                        height: 74,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(width: 3),
                        ),
                        child: CircleAvatar(child: Icon(icons[index])),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        names[index],
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          _card(
            Icons.visibility,
            ar ? 'خصوصية الحالة' : 'Story privacy',
            Column(
              children: <Widget>[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(ar ? 'الأصدقاء المقرّبون فقط' : 'Close Friends only'),
                  value: closeFriends,
                  onChanged: (value) async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('zameel_close_friends_only', value);
                    if (mounted) setState(() => closeFriends = value);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(ar ? 'السماح بالردود' : 'Allow replies'),
                  value: replies,
                  onChanged: (value) async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('zameel_story_replies', value);
                    if (mounted) setState(() => replies = value);
                  },
                ),
              ],
            ),
          ),
          _card(
            Icons.collections_bookmark,
            'Highlights',
            Wrap(
              spacing: 8,
              children: highlights
                  .map(
                    (highlight) => ActionChip(
                      avatar: const Icon(Icons.bookmark, size: 16),
                      label: Text(highlight),
                      onPressed: () => showMessage(
                        ar
                            ? 'يمكنك إضافة الحالة إلى هذا المجلد'
                            : 'You can add a story to this highlight',
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          if (storiesData.isNotEmpty)
            _card(
              Icons.cloud_done,
              ar ? 'حالات منشورة على زميل' : 'Published Zameel stories',
              Column(
                children: storiesData.take(6).map((story) {
                  final String? caption = story['caption'] as String?;
                  final String audience = story['audience'] as String? ?? 'friends';
                  final String mediaType = story['media_type'] as String? ?? 'image';
                  return ListTile(
                    leading: CircleAvatar(
                      child: Icon(mediaType == 'video' ? Icons.videocam : Icons.image),
                    ),
                    title: Text(
                      caption?.isNotEmpty == true ? caption! : 'Zameel Story',
                    ),
                    subtitle: Text(audience),
                  );
                }).toList(),
              ),
            ),
          _preview(storyPath, ar ? 'آخر حالة' : 'Latest story'),
        ],
      ),
    );
  }

  Widget clips() {
    return RefreshIndicator(
      onRefresh: refreshRemote,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _sectionTitle('Zameel Clips', ar ? 'فيديوهات قصيرة للحياة الجامعية' : 'Short videos for campus life'),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _metric('45s', ar ? 'المستخدم العادي' : 'Regular user')),
            const SizedBox(width: 10),
            Expanded(child: _metric('2m', ar ? 'المساهم' : 'Contributor')),
          ]),
          const SizedBox(height: 12),
          if (clipsData.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 30), child: Column(children: [
              const Icon(Icons.video_library_rounded, size: 64), const SizedBox(height: 10),
              Text(ar ? 'لا توجد Clips منشورة بعد' : 'No published Clips yet'),
            ]))
          else
            ...clipsData.map((clip) => _clipCard(clip['video_url']?.toString(), clip['caption']?.toString() ?? 'Campus Clip', clip['id']?.toString())),
          if (clipPath != null) _preview(clipPath, ar ? 'Clip الخاص بك' : 'Your Clip'),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: clipAudience, decoration: InputDecoration(labelText: ar ? 'خصوصية الـClip' : 'Clip privacy', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), items: [
            DropdownMenuItem(value: 'public', child: Text(ar ? '🌍 عامة' : '🌍 Public')),
            DropdownMenuItem(value: 'friends', child: Text(ar ? '👥 للزملاء' : '👥 Colleagues')),
            DropdownMenuItem(value: 'private', child: Text(ar ? '🔒 لي فقط' : '🔒 Only me')),
          ], onChanged: (v) async { if (v == null) return; final prefs = await SharedPreferences.getInstance(); await prefs.setString('zameel_clip_audience', v); if (mounted) setState(() => clipAudience = v); }),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => pickClip(camera: true), icon: const Icon(Icons.videocam_rounded), label: Text(ar ? 'تصوير Clip' : 'Record Clip'))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton.icon(onPressed: () => pickClip(), icon: const Icon(Icons.video_library_rounded), label: Text(ar ? 'من المعرض' : 'From gallery'))),
          ]),
        ],
      ),
    );
  }

  Widget _metric(String value, String label) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        children: <Widget>[
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _clipCard(String? videoUrl, String title, String? id) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (videoUrl != null && videoUrl.isNotEmpty)
          SizedBox(height: 260, child: _ClipVideoPlayer(url: videoUrl, onTap: () => _openClip(videoUrl)))
        else
          Container(height: 180, color: Theme.of(context).colorScheme.surfaceContainerHighest, child: const Center(child: Icon(Icons.video_library_rounded, size: 58))),
        ListTile(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text(ar ? 'فيديو جامعي منشور' : 'Published campus video'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(onPressed: id == null ? null : () async { final was = likedClips.contains(id); try { await ZameelSocialService.toggleClipLike(id, was); if (mounted) setState(() => was ? likedClips.remove(id) : likedClips.add(id)); } catch (_) { showMessage(ar ? 'تعذر تحديث الإعجاب' : 'Could not update like'); } }, icon: Icon(id != null && likedClips.contains(id) ? Icons.favorite : Icons.favorite_border)),
            IconButton(onPressed: id == null ? null : () => showComments(id), icon: const Icon(Icons.comment_outlined)),
          ]),
        ),
      ]),
    );
  }

  void _openClip(String url) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: Text(ar ? 'Clip' : 'Clip')), body: Center(child: _ClipVideoPlayer(url: url, autoPlay: true)))));
  }


  Future<void> showComments(String clipId) async {
    final controller = TextEditingController();
    List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];

    try {
      rows = await ZameelSocialService.loadComments(clipId);
    } catch (_) {
      // Show an empty comments view if the network is unavailable.
    }

    if (!mounted) {
      controller.dispose();
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: SafeArea(
            child: SizedBox(
              height: MediaQuery.of(sheetContext).size.height * 0.65,
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      ar ? 'التعليقات' : 'Comments',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ),
                  Expanded(
                    child: rows.isEmpty
                        ? Center(child: Text(ar ? 'لا توجد تعليقات بعد' : 'No comments yet'))
                        : ListView(
                            children: rows.map((row) {
                              return ListTile(
                                leading: const CircleAvatar(child: Icon(Icons.person)),
                                title: Text(row['text'] as String? ?? ''),
                              );
                            }).toList(),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: ar ? 'اكتب تعليقاً' : 'Write a comment',
                        suffixIcon: IconButton(
                          onPressed: () async {
                            final text = controller.text.trim();
                            if (text.isEmpty) return;
                            try {
                              await ZameelSocialService.addClipComment(clipId, text);
                              if (sheetContext.mounted) Navigator.pop(sheetContext);
                              showMessage(ar ? 'تم نشر التعليق' : 'Comment published');
                            } catch (_) {
                              showMessage(ar ? 'تعذر نشر التعليق' : 'Could not publish comment');
                            }
                          },
                          icon: const Icon(Icons.send),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    controller.dispose();
  }

  Widget notes() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _sectionTitle(
          ar ? 'ملاحظات زميل' : 'Zameel Notes',
          ar
              ? 'رسائل قصيرة للأصدقاء لمدة 24 ساعة'
              : 'Short messages shared with friends for 24 hours',
        ),
        const SizedBox(height: 14),
        TextField(
          controller: note,
          maxLength: 60,
          decoration: InputDecoration(
            hintText: ar ? 'ماذا يدور في بالك؟' : 'What is on your mind?',
            prefixIcon: const Icon(Icons.edit_note),
            suffixIcon: IconButton(
              onPressed: saveNote,
              icon: const Icon(Icons.send),
            ),
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        _noteBubble('سارة', ar ? 'مين عنده ملخص المادة؟ 📚' : 'Who has the course summary? 📚'),
        _noteBubble('أحمد', ar ? 'قهوة بعد المحاضرة؟ ☕' : 'Coffee after the lecture? ☕'),
        _noteBubble('زميل', ar ? 'التسجيل للمسابقة اليوم' : 'Competition registration today'),
        _card(
          Icons.people_alt,
          'Close Friends',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(ar ? 'قائمة خاصة للمحتوى الشخصي' : 'Private audience for personal content'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: friends
                    .map(
                      (friend) => Chip(
                        avatar: CircleAvatar(child: Text(friend.characters.first)),
                        label: Text(friend),
                      ),
                    )
                    .toList(),
              ),
              TextButton.icon(
                onPressed: showCloseFriends,
                icon: const Icon(Icons.person_add_alt_1),
                label: Text(ar ? 'إدارة القائمة' : 'Manage list'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _noteBubble(String name, String text) {
    return Card(
      elevation: 0,
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(text),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => showMessage(
            value == 'report'
                ? (ar ? 'تم الإبلاغ' : 'Reported')
                : (ar ? 'تم كتم الملاحظات' : 'Muted'),
          ),
          itemBuilder: (_) => <PopupMenuEntry<String>>[
            PopupMenuItem(value: 'mute', child: Text(ar ? 'كتم' : 'Mute')),
            PopupMenuItem(value: 'report', child: Text(ar ? 'إبلاغ' : 'Report')),
          ],
        ),
      ),
    );
  }

  Future<void> showCloseFriends() async {
    final Set<String> selected = <String>{};

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(ar ? 'الأصدقاء المقرّبون' : 'Close Friends'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: friends.map((friend) {
                  final bool checked = selected.contains(friend);
                  return CheckboxListTile(
                    value: checked,
                    onChanged: (value) {
                      setDialogState(() {
                        if (value == true) {
                          selected.add(friend);
                        } else {
                          selected.remove(friend);
                        }
                      });
                    },
                    title: Text(friend),
                  );
                }).toList(),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(ar ? 'إغلاق' : 'Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget profile() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Row(
          children: <Widget>[
            const CircleAvatar(radius: 42, child: Icon(Icons.person, size: 40)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    ar ? 'ملفك الاجتماعي' : 'Your social profile',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  Text(ar ? 'طالب • الجامعة الأردنية' : 'Student • University of Jordan'),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      _stat('${clipsData.length}', ar ? 'منشور' : 'Posts'),
                      _stat('0', ar ? 'متابع' : 'Followers'),
                      _stat('0', ar ? 'متابَع' : 'Following'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: creator,
          icon: const Icon(Icons.add),
          label: Text(ar ? 'إنشاء محتوى' : 'Create content'),
        ),
        _card(
          Icons.grid_on,
          'Content grid',
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 9,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemBuilder: (_, index) {
              const icons = <IconData>[
                Icons.school,
                Icons.menu_book,
                Icons.groups,
                Icons.local_cafe,
                Icons.sports_soccer,
              ];
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: Icon(icons[index % icons.length]),
              );
            },
          ),
        ),
        _card(
          Icons.archive,
          'Archive',
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history),
            title: Text(ar ? 'القصص والمنشورات المؤرشفة' : 'Archived stories and posts'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showMessage(ar ? 'الأرشيف جاهز للعرض' : 'Archive opened'),
          ),
        ),
        _card(
          Icons.comment,
          'Comment controls',
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(ar ? 'السماح بالتعليقات على Clips' : 'Allow comments on Clips'),
            value: comments,
            onChanged: (value) async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('zameel_clip_comments', value);
              if (mounted) setState(() => comments = value);
            },
          ),
        ),
      ],
    );
  }

  Widget _stat(String value, String label) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(ar ? 'مجتمع الزملاء' : 'Zameel Community'),
        actions: <Widget>[
          IconButton(onPressed: refreshRemote, icon: const Icon(Icons.sync)),
        ],
        bottom: TabBar(
          controller: tabs,
          tabs: <Widget>[
            Tab(icon: const Icon(Icons.auto_stories), text: ar ? 'الحالات' : 'Stories'),
            const Tab(icon: Icon(Icons.movie_creation), text: 'Clips'),
            Tab(icon: const Icon(Icons.notes), text: ar ? 'ملاحظات' : 'Notes'),
            Tab(icon: const Icon(Icons.person), text: ar ? 'ملفي' : 'Profile'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: creator,
        icon: const Icon(Icons.add),
        label: Text(ar ? 'إنشاء' : 'Create'),
      ),
      body: TabBarView(
        controller: tabs,
        children: <Widget>[stories(), clips(), notes(), profile()],
      ),
    );
  }
}

class VideoFilePreview extends StatefulWidget {
  final String path;
  const VideoFilePreview({super.key, required this.path});

  @override
  State<VideoFilePreview> createState() => _VideoFilePreviewState();
}

class _VideoFilePreviewState extends State<VideoFilePreview> {
  VideoPlayerController? controller;

  @override
  void initState() {
    super.initState();
    final Uri? uri = Uri.tryParse(widget.path);
    if (kIsWeb && uri != null && uri.hasScheme) {
      controller = VideoPlayerController.networkUrl(uri);
    } else {
      controller = null;
    }
    controller?.initialize().then((_) {
      if (mounted) setState(() {});
    }).catchError((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final VideoPlayerController? video = controller;
    if (video == null || !video.value.isInitialized) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        child: const Icon(Icons.videocam_off_outlined, size: 48),
      );
    }

    return GestureDetector(
      onTap: () {
        if (video.value.isPlaying) {
          video.pause();
        } else {
          video.play();
        }
        setState(() {});
      },
      child: AspectRatio(
        aspectRatio: video.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            VideoPlayer(video),
            if (!video.value.isPlaying)
              const CircleAvatar(
                radius: 28,
                child: Icon(Icons.play_arrow),
              ),
          ],
        ),
      ),
    );
  }
}

class _ClipVideoPlayer extends StatefulWidget {
  final String url; final bool autoPlay; final VoidCallback? onTap;
  const _ClipVideoPlayer({required this.url, this.autoPlay = true, this.onTap});
  @override State<_ClipVideoPlayer> createState() => _ClipVideoPlayerState();
}
class _ClipVideoPlayerState extends State<_ClipVideoPlayer> {
  late final VideoPlayerController _controller;
  Object? _error;
  @override void initState() { super.initState(); _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url)); _initialize(); }
  Future<void> _initialize() async {
    try { await _controller.initialize(); if (!mounted) return; setState(() {}); if (widget.autoPlay) await _controller.play(); }
    catch (e) { if (mounted) setState(() => _error = e); }
  }
  @override void dispose() { _controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    if (_error != null) return Center(child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.error_outline_rounded, size: 40), const SizedBox(height: 8), const Text('تعذر تشغيل هذا الفيديو', style: TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 6), Text(_error.toString(), maxLines: 3, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.grey))])));
    if (!_controller.value.isInitialized) return const Center(child: CircularProgressIndicator());
    return GestureDetector(onTap: widget.onTap ?? () { setState(() { _controller.value.isPlaying ? _controller.pause() : _controller.play(); }); }, child: Stack(fit: StackFit.expand, children: [FittedBox(fit: BoxFit.contain, child: SizedBox(width: _controller.value.size.width, height: _controller.value.size.height, child: VideoPlayer(_controller))), if (!_controller.value.isPlaying) const Center(child: CircleAvatar(radius: 30, child: Icon(Icons.play_arrow_rounded, size: 34)))]));
  }
}
