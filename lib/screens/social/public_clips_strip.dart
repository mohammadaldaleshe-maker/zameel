
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../../services_social.dart';
import '../../services/media_cache_service.dart';
import '../../providers/language_provider.dart';
import '../../widgets/vertical_autoplay_video_player.dart';
import '../profile/profile_screen.dart';
import '../comments/clip_comments_screen.dart';
import 'clip_create_screen.dart';
import '../../theme/app_theme.dart';
import '../../platform/video_controller_factory.dart';

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
      final visible = rows
          .where((c) => c['audience'] == 'public' && c['is_hidden'] != true)
          .take(12)
          .toList();
      if (mounted) {
        setState(() => _clips = visible);
      }
      // Do not pre-download six full clips merely because the strip loaded.
      // The 1.5-second preview streams lightly; opening the viewer performs a
      // single cache-aware download of the chosen clip.
    } catch (_) {
      if (mounted) setState(() => _clips = const []);
    } finally {
      if (mounted && (!silent || _loading)) setState(() => _loading = false);
    }
  }

  Future<void> _comment(Map<String, dynamic> clip) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ClipCommentsScreen(clip: clip)),
    );
    await _load(silent: true);
  }

  Future<void> _like(Map<String, dynamic> clip) async {
    final id = clip['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final liked = clip['liked'] == true;
    final oldCount = (clip['likes_count'] as num?)?.toInt() ?? 0;
    if (mounted) {
      setState(() {
        clip['liked'] = !liked;
        clip['likes_count'] = (oldCount + (liked ? -1 : 1)).clamp(0, 999999);
      });
    }
    try {
      await ZameelSocialService.toggleClipLike(id, liked);
    } catch (_) {
      if (mounted) {
        setState(() {
          clip['liked'] = liked;
          clip['likes_count'] = oldCount;
        });
      }
    }
  }

  Future<void> _share(Map<String, dynamic> clip) async {
    await ZameelSocialService.shareClip(clip['id'].toString());
    await SharePlus.instance.share(
      ShareParams(text: 'شاهد هذا المقطع على زميل: zameel://clip/${clip['id']}'),
    );
  }

  Future<void> _addClip() async {
    final ar = Provider.of<LanguageProvider>(context, listen: false).isArabic;
    final published = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ClipCreateScreen(isArabic: ar),
      ),
    );
    if (published == true) {
      await _load(silent: true);
    }
  }

  Future<void> _open(Map<String, dynamic> clip) async {
    final url = clip['video_url']?.toString() ?? '';
    if (url.isEmpty) return;
    final initialIndex = _clips.indexWhere(
      (item) => item['id']?.toString() == clip['id']?.toString(),
    );
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _VerticalClipsViewer(
          clips: _clips,
          initialIndex: initialIndex < 0 ? 0 : initialIndex,
        ),
      ),
    );
    await _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final ar = Provider.of<LanguageProvider>(context).isArabic;
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SizedBox(
        height: 194,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: 1 + (_loading ? 0 : _clips.length),
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            if (i == 0) return _addClipCard(ar);
            final clipIndex = i - 1;
            final clip = _clips[clipIndex];
            final owner = clip['users'] is Map
                ? Map<String, dynamic>.from(clip['users'] as Map)
                : const <String, dynamic>{};
            final publisher = (owner['name']?.toString() ?? '').trim();
            return InkWell(
              onTap: () => _open(clip),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 116,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  gradient: AppTheme.signatureGradient,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: SizedBox(
                    width: 112,
                    height: 190,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _ClipAutoPreview(
                          url: clip['video_url']?.toString() ?? '',
                          autoplay: clipIndex < 4,
                        ),
                        const Center(
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                        Positioned(
                          top: 7,
                          right: 7,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    clip['liked'] == true
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    color: clip['liked'] == true
                                        ? Colors.redAccent
                                        : Colors.white,
                                    size: 13,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${clip['likes_count'] ?? 0}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(7, 14, 7, 7),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black87],
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 8,
                                  backgroundImage: owner['profile_image']
                                              ?.toString()
                                              .isNotEmpty ==
                                          true
                                      ? NetworkImage(
                                          owner['profile_image'].toString(),
                                        )
                                      : null,
                                  child: owner['profile_image']
                                              ?.toString()
                                              .isNotEmpty ==
                                          true
                                      ? null
                                      : const Icon(Icons.person, size: 10),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    publisher.isEmpty ? 'زميل' : publisher,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
      ),
    );
  }

  Widget _addClipCard(bool ar) {
    return InkWell(
      onTap: _addClip,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        width: 116,
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: AppTheme.primary, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AppTheme.signatureGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 10),
            Text(
              ar ? 'إضافة كليبس' : 'Add clip',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            if (_loading) ...[
              const SizedBox(height: 8),
              const SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
      ),
    );
  }

}

class _VerticalClipsViewer extends StatefulWidget {
  final List<Map<String, dynamic>> clips;
  final int initialIndex;

  const _VerticalClipsViewer({
    required this.clips,
    required this.initialIndex,
  });

  @override
  State<_VerticalClipsViewer> createState() => _VerticalClipsViewerState();
}

class _VerticalClipsViewerState extends State<_VerticalClipsViewer> {
  late final PageController _pageController;
  late List<Map<String, dynamic>> _clips;
  late int _currentIndex;
  bool _controlsVisible = true;

  @override
  void initState() {
    super.initState();
    _clips = widget.clips.map(Map<String, dynamic>.from).toList();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _prefetchAround(_currentIndex);
  }

  void _prefetchAround(int index) {
    // Current clip downloads itself. Prefetch only the next clip to avoid
    // burning egress on several full videos that may never be opened.
    final next = index + 1;
    if (next < 0 || next >= _clips.length) return;
    final url = _clips[next]['video_url']?.toString() ?? '';
    if (url.isNotEmpty) {
      unawaited(MediaCacheService.prefetch(<String>[url], limit: 1));
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _delete(Map<String, dynamic> clip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الكليبس؟'),
        content: const Text(
          'سيتم حذف هذا الكليبس نهائيًا من جميع أماكن ظهوره.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ZameelSocialService.deleteClip(clip['id'].toString());
      if (!mounted) return;
      setState(() => _clips.removeWhere(
          (item) => item['id']?.toString() == clip['id']?.toString()));
      if (_clips.isEmpty) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حذف الكليبس: $error')),
        );
      }
    }
  }

  Future<void> _like(Map<String, dynamic> clip) async {
    final id = clip['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final liked = clip['liked'] == true;
    final oldCount = (clip['likes_count'] as num?)?.toInt() ?? 0;
    setState(() {
      clip['liked'] = !liked;
      clip['likes_count'] = (oldCount + (liked ? -1 : 1)).clamp(0, 999999);
    });
    try {
      await ZameelSocialService.toggleClipLike(id, liked);
    } catch (_) {
      if (mounted) {
        setState(() {
          clip['liked'] = liked;
          clip['likes_count'] = oldCount;
        });
      }
    }
  }

  Future<void> _share(Map<String, dynamic> clip) async {
    await ZameelSocialService.shareClip(clip['id'].toString());
    await SharePlus.instance.share(
      ShareParams(text: 'شاهد هذا المقطع على زميل: zameel://clip/${clip['id']}'),
    );
  }

  Future<void> _comment(Map<String, dynamic> clip) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ClipCommentsScreen(clip: clip)),
    );
    final engagement = await ZameelSocialService.loadClipEngagement(
      clip['id']?.toString() ?? '',
    );
    if (!mounted || engagement == null) return;
    setState(() {
      clip['likes_count'] = engagement['likes_count'] ?? clip['likes_count'];
      clip['comments_count'] =
          engagement['comments_count'] ?? clip['comments_count'];
      clip['liked'] = engagement['liked'] == true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = Supabase.instance.client.auth.currentUser?.id;
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _clips.length,
        onPageChanged: (index) {
          if (mounted) setState(() {
            _currentIndex = index;
            _controlsVisible = true;
          });
          _prefetchAround(index);
        },
        itemBuilder: (_, index) {
          final clip = _clips[index];
          final owner = clip['users'] is Map
              ? Map<String, dynamic>.from(clip['users'] as Map)
              : const <String, dynamic>{};
          final ownerId = clip['user_id']?.toString();
          final name = owner['name']?.toString() ?? 'زميل';
          final image = owner['profile_image']?.toString() ?? '';
          final mine = ownerId != null && ownerId == me;
          return SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: index == _currentIndex
                      ? VerticalAutoplayVideoPlayer(
                          videoUrl: clip['video_url']?.toString() ?? '',
                          onControlsVisibilityChanged: (visible) {
                            if (mounted && _controlsVisible != visible) setState(() => _controlsVisible = visible);
                          },
                        )
                      : const ColoredBox(
                          color: Colors.black,
                          child: Center(
                            child: Icon(
                              Icons.play_circle_outline_rounded,
                              color: Colors.white38,
                              size: 54,
                            ),
                          ),
                        ),
                ),
                if (_controlsVisible) Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton.filledTonal(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
                if (_controlsVisible) Positioned(
                  left: 12,
                  right: 12,
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(185),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundImage:
                                image.isNotEmpty ? NetworkImage(image) : null,
                            child: image.isEmpty
                                ? const Icon(Icons.person_rounded)
                                : null,
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: (clip['caption']?.toString() ?? '').isEmpty
                              ? null
                              : Text(
                                  clip['caption'].toString(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                          trailing: mine
                              ? IconButton(
                                  tooltip: 'حذف الكليبس',
                                  onPressed: () => _delete(clip),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.redAccent,
                                  ),
                                )
                              : null,
                          onTap: ownerId == null
                              ? null
                              : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ProfileScreen(userId: ownerId),
                                    ),
                                  ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton.icon(
                              onPressed: () => _like(clip),
                              icon: Icon(
                                clip['liked'] == true
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: clip['liked'] == true
                                    ? Colors.redAccent
                                    : null,
                              ),
                              label: Text('${clip['likes_count'] ?? 0}'),
                            ),
                            TextButton.icon(
                              onPressed: () => _comment(clip),
                              icon: const Icon(Icons.chat_bubble_outline),
                              label: Text('${clip['comments_count'] ?? 0}'),
                            ),
                            TextButton.icon(
                              onPressed: () => _share(clip),
                              icon: const Icon(Icons.share_outlined),
                              label: const Text('مشاركة'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
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
    if (widget.url.isEmpty || !widget.autoplay) return;
    // Preview only 1.5 seconds. Never combine a network stream with a full
    // background prefetch of the same clip; reuse cache only when it exists.
    final cachedPath = kIsWeb
        ? null
        : await MediaCacheService.localPathForUrl(
            widget.url,
            downloadIfMissing: false,
          );
    final c = !kIsWeb && cachedPath != null
        ? videoControllerFromLocalPath(cachedPath)
        : VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = c;
    try {
      await c.initialize();
      await c.setVolume(0);
      await c.seekTo(Duration.zero);
      await c.play();
      _timer = Timer(const Duration(milliseconds: 1500), () {
        c.pause();
        c.seekTo(Duration.zero);
      });
      if (mounted) setState(() {});
    } catch (_) {}
  }
  @override void dispose(){_timer?.cancel();_controller?.dispose();super.dispose();}
  @override Widget build(BuildContext context){final c=_controller;if(c==null||!c.value.isInitialized)return const ColoredBox(color:Colors.black87,child:Icon(Icons.video_library_outlined,color:Colors.white54));return FittedBox(fit:BoxFit.cover,child:SizedBox(width:c.value.size.width,height:c.value.size.height,child:VideoPlayer(c)));}
}
