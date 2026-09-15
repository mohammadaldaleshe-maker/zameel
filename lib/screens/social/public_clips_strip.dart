import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';

import '../../services_social.dart';
import '../../widgets/video_player_widget.dart';
import '../profile/profile_screen.dart';
import '../../theme/app_theme.dart';

class PublicClipsStrip extends StatefulWidget {
  const PublicClipsStrip({super.key});
  @override
  State<PublicClipsStrip> createState() => _PublicClipsStripState();
}

class _PublicClipsStripState extends State<PublicClipsStrip> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _clips = const [];
  bool _loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) => _load(silent: true));
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
      _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) => _load(silent: true));
      _load(silent: true);
    } else {
      _refreshTimer?.cancel();
    }
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final rows = await ZameelSocialService.loadClips();
      if (mounted) {
        setState(() => _clips = rows
            .where((c) => c['audience'] == 'public' && c['is_hidden'] != true)
            .take(12)
            .toList());
      }
    } catch (_) {
      if (mounted) setState(() => _clips = const []);
    } finally {
      if (mounted && (!silent || _loading)) setState(() => _loading = false);
    }
  }

  Future<void> _comment(Map<String,dynamic> clip) async {
    final c = TextEditingController();
    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة تعليق'),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'اكتب تعليقك...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إرسال')),
        ],
      ),
    );
    final text = c.text.trim();
    c.dispose();
    if (send == true && text.isNotEmpty) {
      await ZameelSocialService.addClipComment(clip['id'].toString(), text);
      if (mounted) {
        setState(() => clip['comments_count'] =
            ((clip['comments_count'] ?? 0) as num).toInt() + 1);
      }
    }
  }

  Future<void> _like(Map<String, dynamic> clip) async {
    final id = clip['id'].toString();
    final liked = await ZameelSocialService.isClipLiked(id);
    await ZameelSocialService.toggleClipLike(id, liked);
    if (mounted) {
      setState(() => clip['likes_count'] =
          (((clip['likes_count'] ?? 0) as num).toInt() + (liked ? -1 : 1))
              .clamp(0, 999999));
    }
  }

  Future<void> _share(Map<String, dynamic> clip) async {
    await ZameelSocialService.shareClip(clip['id'].toString());
    await SharePlus.instance.share(
      ShareParams(text: 'شاهد هذا المقطع على زميل: zameel://clip/${clip['id']}'),
    );
  }

  void _open(Map<String, dynamic> clip) {
    final url = clip['video_url']?.toString() ?? '';
    if (url.isEmpty) return;
    final user = clip['users'] is Map ? clip['users'] as Map : const <String,dynamic>{};
    final ownerId = clip['user_id']?.toString();
    final image = user['profile_image']?.toString() ?? '';
    final name = user['name']?.toString() ?? 'زميل';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('كليبس عام')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(backgroundImage: image.isNotEmpty ? NetworkImage(image) : null, child: image.isEmpty ? const Icon(Icons.person) : null),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  onTap: ownerId == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: ownerId))),
                ),
                VideoPlayerWidget(videoUrl: url),
                if ((clip['caption']?.toString() ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(clip['caption'].toString(),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  TextButton.icon(onPressed: () => _like(clip), icon: const Icon(Icons.favorite_border), label: Text('${clip['likes_count'] ?? 0}')),
                  TextButton.icon(onPressed: () => _comment(clip), icon: const Icon(Icons.chat_bubble_outline), label: Text('${clip['comments_count'] ?? 0}')),
                  TextButton.icon(onPressed: () => _share(clip), icon: const Icon(Icons.share_outlined), label: const Text('مشاركة')),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(height: 88, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }
    if (_clips.isEmpty) return const SizedBox.shrink();
    return Container(
      color: AppTheme.background,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          height: 214,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _clips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final clip = _clips[i];
              final owner = clip['users'] is Map ? clip['users'] as Map : const {};
              final publisher = (owner['name']?.toString() ?? '').trim();
              return InkWell(
                onTap: () => _open(clip),
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 116,
                  child: Column(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 116,
                        height: 178,
                        child: Stack(fit: StackFit.expand, children: [
                          _ClipAutoPreview(url: clip['video_url']?.toString() ?? '', autoplay: i < 4),
                          const Center(child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(children:[CircleAvatar(radius:8,backgroundImage:(owner['profile_image']?.toString().isNotEmpty==true)?NetworkImage(owner['profile_image'].toString()):null,child:owner['profile_image']?.toString().isNotEmpty==true?null:const Icon(Icons.person,size:10)),const SizedBox(width:5),Expanded(child:Text(publisher.isEmpty?'زميل':publisher,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700)))]),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _ClipAutoPreview extends StatefulWidget {
  final String url;
  final bool autoplay;
  const _ClipAutoPreview({required this.url, required this.autoplay});
  @override State<_ClipAutoPreview> createState() => _ClipAutoPreviewState();
}

class _ClipAutoPreviewState extends State<_ClipAutoPreview> {
  VideoPlayerController? _controller;
  Timer? _timer;
  @override void initState(){super.initState();_prepare();}
  Future<void> _prepare() async {
    if(widget.url.isEmpty || !widget.autoplay)return;
    final c=VideoPlayerController.networkUrl(Uri.parse(widget.url));_controller=c;
    try{await c.initialize();await c.setVolume(0);await c.seekTo(Duration.zero);await c.play();_timer=Timer(const Duration(milliseconds:1500),(){c.pause();c.seekTo(Duration.zero);});if(mounted)setState((){});}catch(_){}
  }
  @override void dispose(){_timer?.cancel();_controller?.dispose();super.dispose();}
  @override Widget build(BuildContext context){final c=_controller;if(c==null||!c.value.isInitialized)return const ColoredBox(color:Colors.black87,child:Icon(Icons.video_library_outlined,color:Colors.white54));return FittedBox(fit:BoxFit.cover,child:SizedBox(width:c.value.size.width,height:c.value.size.height,child:VideoPlayer(c)));}
}
