import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services_social.dart';
import '../../widgets/video_player_widget.dart';

class ZameelSocialStudio extends StatefulWidget {
  final bool isArabic;
  const ZameelSocialStudio({super.key, required this.isArabic});

  @override
  State<ZameelSocialStudio> createState() => _ZameelSocialStudioState();
}

class _ZameelSocialStudioState extends State<ZameelSocialStudio> {
  final ImagePicker _picker = ImagePicker();
  List<Map<String, dynamic>> _clips = <Map<String, dynamic>>[];
  bool _loading = true;
  bool _publishing = false;

  bool get ar => widget.isArabic;
  String? get uid => ZameelSocialService.uid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final rows = await ZameelSocialService.loadClips();
      if (mounted) setState(() => _clips = rows);
    } catch (_) {
      _message(ar ? 'تعذر تحميل مقاطع الفيديو' : 'Could not load videos');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<_ClipDraft?> _askPublishOptions() async {
    final caption = TextEditingController();
    var audience = 'public';
    final result = await showDialog<_ClipDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text(ar ? 'نشر مقطع فيديو' : 'Publish video'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: caption, maxLength: 300, decoration: InputDecoration(labelText: ar ? 'وصف اختياري' : 'Optional caption')),
            DropdownButtonFormField<String>(
              value: audience,
              decoration: InputDecoration(labelText: ar ? 'من يمكنه المشاهدة؟' : 'Who can watch?'),
              items: [
                DropdownMenuItem(value: 'public', child: Text(ar ? 'العامة' : 'Public')),
                DropdownMenuItem(value: 'friends', child: Text(ar ? 'الأصدقاء' : 'Friends')),
                DropdownMenuItem(value: 'private', child: Text(ar ? 'خاص — أنا فقط' : 'Private — only me')),
              ],
              onChanged: (value) => setDialogState(() => audience = value ?? 'public'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(ar ? 'إلغاء' : 'Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, _ClipDraft(caption.text.trim(), audience)), child: Text(ar ? 'متابعة' : 'Continue')),
          ],
        ),
      ),
    );
    caption.dispose();
    return result;
  }

  Future<void> _publish() async {
    final file = await _picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 120));
    if (file == null) return;
    final draft = await _askPublishOptions();
    if (draft == null || !mounted) return;
    setState(() => _publishing = true);
    try {
      final bytes = await file.readAsBytes();
      final id = await ZameelSocialService.createClipBytes(bytes: bytes, filename: file.name, caption: draft.caption, durationSeconds: 120, audience: draft.audience);
      if (id == null) throw StateError('clip_not_created');
      await _load();
      _message(ar ? 'تم نشر الفيديو' : 'Video published');
    } catch (_) {
      _message(ar ? 'تعذر نشر الفيديو. تحقق من الاتصال وحاول مجددًا.' : 'Could not publish the video. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _manage(Map<String, dynamic> clip, String action) async {
    final id = clip['id']?.toString();
    if (id == null) return;
    try {
      if (action == 'delete') {
        final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
          title: Text(ar ? 'حذف الفيديو؟' : 'Delete video?'),
          content: Text(ar ? 'سيُحذف المقطع وتفاعلاته نهائيًا.' : 'The video and its interactions will be deleted permanently.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(ar ? 'إلغاء' : 'Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(ar ? 'حذف' : 'Delete')),
          ],
        ));
        if (confirmed != true) return;
        await ZameelSocialService.deleteClip(id);
      } else if (action == 'hide') {
        await ZameelSocialService.updateClip(id, hidden: clip['is_hidden'] != true);
      } else {
        await ZameelSocialService.updateClip(id, audience: action);
      }
      await _load();
    } catch (_) {
      _message(ar ? 'تعذر تحديث الفيديو' : 'Could not update the video');
    }
  }

  String _audienceLabel(String value) {
    if (value == 'private') return ar ? 'أنا فقط' : 'Only me';
    if (value == 'friends') return ar ? 'الأصدقاء' : 'Friends';
    return ar ? 'العامة' : 'Public';
  }

  void _open(Map<String, dynamic> clip) {
    final url = clip['video_url']?.toString() ?? '';
    if (url.isEmpty) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      appBar: AppBar(title: Text(ar ? 'مقطع فيديو' : 'Video')),
      body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
        ClipRRect(borderRadius: BorderRadius.circular(18), child: VideoPlayerWidget(videoUrl: url)),
        if ((clip['caption']?.toString() ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(clip['caption'].toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
        ],
      ])))),
    )));
  }

  Widget _card(Map<String, dynamic> clip) {
    final url = clip['video_url']?.toString() ?? '';
    final mine = clip['user_id']?.toString() == uid;
    final hidden = clip['is_hidden'] == true;
    final audience = clip['audience']?.toString() ?? 'public';
    final caption = (clip['caption']?.toString() ?? '').trim();
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(onTap: () => _open(clip), child: SizedBox(height: 230, child: Stack(fit: StackFit.expand, children: [
          if (url.isNotEmpty) VideoPlayerWidget(videoUrl: url) else const ColoredBox(color: Colors.black12, child: Icon(Icons.video_library_outlined, size: 60)),
          const Center(child: CircleAvatar(radius: 27, backgroundColor: Colors.black45, child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34))),
          if (hidden) Positioned(top: 10, left: 10, child: Chip(avatar: const Icon(Icons.visibility_off, size: 17), label: Text(ar ? 'مخفي' : 'Hidden'))),
        ]))),
        Padding(padding: const EdgeInsets.fromLTRB(14, 10, 8, 12), child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(caption.isEmpty ? (ar ? 'مقطع فيديو' : 'Video') : caption, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${_audienceLabel(audience)} · ${clip['likes_count'] ?? 0} ♥ · ${clip['comments_count'] ?? 0} 💬', style: Theme.of(context).textTheme.bodySmall),
          ])),
          if (mine) PopupMenuButton<String>(
            tooltip: ar ? 'إدارة الفيديو' : 'Manage video',
            onSelected: (value) => _manage(clip, value),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'public', child: Text(ar ? 'جعله عامًا' : 'Make public')),
              PopupMenuItem(value: 'friends', child: Text(ar ? 'للأصدقاء فقط' : 'Friends only')),
              PopupMenuItem(value: 'private', child: Text(ar ? 'خاص — أنا فقط' : 'Private — only me')),
              PopupMenuItem(value: 'hide', child: Text(hidden ? (ar ? 'إظهار الفيديو' : 'Show video') : (ar ? 'إخفاء الفيديو' : 'Hide video'))),
              PopupMenuItem(value: 'delete', child: Text(ar ? 'حذف الفيديو' : 'Delete video', style: const TextStyle(color: Colors.red))),
            ],
          ),
        ])),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(ar ? 'مقاطع الفيديو' : 'Videos')),
        body: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _clips.isEmpty
                  ? ListView(children: [SizedBox(height: MediaQuery.sizeOf(context).height * .25), Icon(Icons.video_library_outlined, size: 68, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 12), Text(ar ? 'لا توجد مقاطع فيديو بعد' : 'No videos yet', textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800))])
                  : ListView.builder(padding: const EdgeInsets.only(bottom: 100), itemCount: _clips.length, itemBuilder: (_, index) => _card(_clips[index])),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _publishing ? null : _publish,
          icon: _publishing ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_rounded),
          label: Text(ar ? 'نشر فيديو' : 'Publish video'),
        ),
      ),
    );
  }
}

class _ClipDraft {
  final String caption;
  final String audience;
  const _ClipDraft(this.caption, this.audience);
}
