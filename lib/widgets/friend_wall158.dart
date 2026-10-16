import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/background_publish156.dart';
import '../services/post_presentation157.dart';
import '../services/video_source_service.dart';
import 'package:video_player/video_player.dart';
import '../screens/profile/profile_screen.dart';
import 'copyable_text.dart';

class FriendWall158 extends StatefulWidget {
  const FriendWall158({super.key, required this.owner});
  final String owner;
  @override
  State<FriendWall158> createState() => _FriendWall158State();
}

class _FriendWall158State extends State<FriendWall158> {
  final db = Supabase.instance.client;
  List<Map<String, dynamic>> rows = [];
  bool canPost = false, busy = false, more = true;
  String? birth;
  final _urls = <String, Future<String>>{};
  @override
  void initState() {
    super.initState();
    BackgroundPublish156.revision.addListener(_refresh158);
    _load();
  }

  void _refresh158() {
    if (mounted) _load();
  }

  @override
  void dispose() {
    BackgroundPublish156.revision.removeListener(_refresh158);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FriendWall158 old) {
    super.didUpdateWidget(old);
    if (old.owner != widget.owner) {
      rows = [];
      _urls.clear();
      _load();
    }
  }

  Future<void> _load({bool next = false}) async {
    try {
      final settings = await db.rpc('zameel_member_settings_read158',
          params: {'p_owner': widget.owner});
      final data = List<Map<String, dynamic>>.from(await db
          .rpc('zameel_wall_list158', params: {
        'p_owner': widget.owner,
        'p_offset': next ? rows.length : 0
      }));
      if (mounted)
        setState(() {
          canPost = settings['can_post'] == true;
          birth = settings['birth_date']?.toString();
          rows = next ? [...rows, ...data] : data;
          more = data.length == 30;
        });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر تحميل منشورات الأصدقاء')));
    }
  }

  Future<String> _url(String path) => _urls.putIfAbsent(
      path, () => db.storage.from('zameel_wall158').createSignedUrl(path, 60));
  Future<void> _compose() async {
    final controller = TextEditingController();
    final files = <XFile>[];
    final accepted = await showDialog<bool>(
        context: context,
        builder: (c) => StatefulBuilder(
            builder: (c, change) => AlertDialog(
                    title: const Text('اكتب على صفحة صديقك'),
                    content: SizedBox(
                        width: 480,
                        child: SingleChildScrollView(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                              TextField(
                                  controller: controller,
                                  maxLines: 4,
                                  maxLength: 10000,
                                  decoration: const InputDecoration(
                                      hintText: 'اكتب تهنئتك أو منشورك…')),
                              TextButton.icon(
                                  icon: const Icon(Icons.perm_media),
                                  label: const Text('صور وفيديوهات'),
                                  onPressed: () async {
                                    final picked = await ImagePicker()
                                        .pickMultipleMedia(limit: 10);
                                    if (c.mounted)
                                      change(() {
                                        files.addAll(
                                            picked.take(10 - files.length));
                                      });
                                  }),
                              for (final f in files)
                                ListTile(
                                    title: Text(f.name),
                                    trailing: IconButton(
                                        icon: const Icon(Icons.close),
                                        onPressed: () =>
                                            change(() => files.remove(f)))),
                            ]))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('إلغاء')),
                      FilledButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('نشر'))
                    ])));
    final text = controller.text.trim();
    controller.dispose();
    if (accepted != true || (text.isEmpty && files.isEmpty)) return;
    if (db.auth.currentUser == null) return;
    setState(() => busy = true);
    try {
      await BackgroundPublish156.wall(
          owner: widget.owner, text: text, files: files);
      if (mounted) await BackgroundPublish156.notice(context);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر تجهيز المنشور للنشر')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (c) =>
            AlertDialog(title: const Text('حذف المنشور من الصفحة؟'), actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('إلغاء')),
              FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('حذف'))
            ]));
    if (ok != true) return;
    try {
      await db.rpc('zameel_wall_delete158', params: {'p_id': id});
      await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تعذر حذف المنشور')));
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (birth != null)
          Padding(
              padding: const EdgeInsets.all(12),
              child: Text('تاريخ الميلاد: $birth')),
        if (canPost)
          Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                  onPressed: busy ? null : _compose,
                  icon: const Icon(Icons.edit),
                  label: Text(busy ? 'جارٍ النشر…' : 'اكتب على صفحة صديقك'))),
        if (rows.isNotEmpty)
          const Padding(
              padding: EdgeInsets.all(12),
              child: Text('منشورات الأصدقاء',
                  style: TextStyle(fontWeight: FontWeight.bold))),
        for (final row in rows)
          Card(
              margin: const EdgeInsets.all(12),
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: TextButton(
                                  onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => ProfileScreen(
                                              userId: '${row['author_id']}'))),
                                  child: Row(children: [
                                    CircleAvatar(
                                        backgroundImage: (row['author_photo']
                                                    ?.toString()
                                                    .isNotEmpty ??
                                                false)
                                            ? NetworkImage(
                                                '${row['author_photo']}')
                                            : null,
                                        child: (row['author_photo']
                                                    ?.toString()
                                                    .isNotEmpty ??
                                                false)
                                            ? null
                                            : const Icon(Icons.person)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: Text('${row['author_name']}'))
                                  ]))),
                          if ([row['author_id'], row['owner_id']]
                              .contains(db.auth.currentUser?.id))
                            IconButton(
                                onPressed: () => _delete('${row['id']}'),
                                icon: const Icon(Icons.delete_outline))
                        ]),
                        Text(relativePostTime158(row['created_at'])),
                        CopyableText('${row['content']}'),
                        for (final item in row['media'] as List)
                          FutureBuilder<String>(
                              future: _url('${item['path']}'),
                              builder: (c, s) {
                                if (!s.hasData)
                                  return const SizedBox(
                                      height: 100,
                                      child: Center(
                                          child: CircularProgressIndicator()));
                                return item['type'] == 'video'
                                    ? _WallVideo158(url: s.data!)
                                    : Image.network(s.data!,
                                        errorBuilder: (_, __, ___) =>
                                            const Text('تعذر عرض الصورة'));
                              }),
                      ]))),
        if (more && rows.isNotEmpty)
          TextButton(
              onPressed: () => _load(next: true),
              child: const Text('عرض المزيد')),
      ]);
}

class _WallVideo158 extends StatefulWidget {
  const _WallVideo158({required this.url});
  final String url;
  @override
  State<_WallVideo158> createState() => _WallVideo158State();
}

class _WallVideo158State extends State<_WallVideo158> {
  VideoPlayerController? controller;
  bool _failed = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _WallVideo158 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _generation++;
      controller?.dispose();
      controller = null;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    VideoPlayerController? candidate;
    try {
      candidate = await VideoSourceService.controller(widget.url);
      if (!mounted || generation != _generation) {
        await candidate.dispose();
        return;
      }
      await candidate.initialize().timeout(const Duration(seconds: 15));
      if (!mounted || generation != _generation) {
        await candidate.dispose();
        return;
      }
      setState(() {
        controller = candidate;
        _failed = false;
      });
    } catch (_) {
      await candidate?.dispose();
      if (mounted && generation == _generation) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c == null && _failed)
      return SizedBox(
          height: 120,
          child: Center(
              child: TextButton(
                  onPressed: () {
                    setState(() => _failed = false);
                    _load();
                  },
                  child: const Text('تعذر تشغيل الفيديو، حاول مجددًا'))));
    if (c == null)
      return const SizedBox(
          height: 120, child: Center(child: Text('جارٍ تجهيز الفيديو')));
    return Column(children: [
      AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c)),
      IconButton(
          onPressed: () {
            setState(() {
              c.value.isPlaying ? c.pause() : c.play();
            });
          },
          icon: Icon(c.value.isPlaying ? Icons.pause : Icons.play_arrow)),
      VideoProgressIndicator(c, allowScrubbing: true)
    ]);
  }
}
