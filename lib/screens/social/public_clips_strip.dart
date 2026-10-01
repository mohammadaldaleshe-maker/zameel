import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart';
import '../../services/feature_control.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../../services_social.dart';
import '../../services/media_cache_service.dart';
import '../../providers/language_provider.dart';
import '../../widgets/vertical_autoplay_video_player.dart';
import '../../widgets/post_report_menu.dart';
import '../profile/profile_screen.dart';
import '../comments/clip_comments_screen.dart';
import 'clip_create_screen.dart';
import '../../theme/app_theme.dart';
import '../../services/video_source_service.dart';
import '../../services/secure_media_service.dart';
import '../../services/home_snapshot_service.dart';

class PublicClipsStrip extends StatefulWidget {
  const PublicClipsStrip({super.key});
  @override
  State<PublicClipsStrip> createState() => _PublicClipsStripState();
}

class _PublicClipsStripState extends State<PublicClipsStrip> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _clips = const [];
  bool _loading = true;
  Timer? _refreshTimer;
  bool _refreshing = false;
  bool _remoteShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restoreClips();
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

  Future<void> _restoreClips() async {
    final userId = ZameelSocialService.uid;
    if (userId == null) return;
    final cached = await HomeSnapshotService.read(userId, 'clips');
    if (!mounted || _remoteShown || ZameelSocialService.uid != userId || cached.isEmpty) return;
    setState(() { _clips = cached; _loading = false; });
  }

  Future<void> _load({bool silent = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    final userId = ZameelSocialService.uid;
    try {
      final rows = await ZameelSocialService.loadClips(resolveMedia: false)
          .timeout(const Duration(seconds: 15));
      if (!mounted || ZameelSocialService.uid != userId) return;
      _remoteShown = true;
      final visible = rows
          .where((c) => c['audience'] == 'public' && c['is_hidden'] != true)
          .take(12)
          .toList();
      if (mounted) {
        setState(() => _clips = visible);
      }
      if (userId != null) unawaited(HomeSnapshotService.save(userId, 'clips', visible));
      // Do not pre-download six full clips merely because the strip loaded.
      // The 1.5-second preview streams lightly; opening the viewer performs a
      // single cache-aware download of the chosen clip.
    } catch (_) {
      // Keep the already visible strip during a failed background refresh.
      // Retain the last successfully loaded list on a network failure.
    } finally {
      _refreshing = false;
      if (mounted && (!silent || _loading)) setState(() => _loading = false);
    }
  }

  Future<void> _comment(Map<String, dynamic> clip) async {
    if (!await FeatureControl.instance.check(context, 'comments')) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FeatureControl.instance.page('comments', ClipCommentsScreen(clip: clip))),
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
              key: ValueKey(clip['id']),
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
              ar ? 'إضافة شورتس' : 'Add clip',
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
  final String? authorId;
  final bool savedOnly;

  const _VerticalClipsViewer({
    required this.clips,
    required this.initialIndex,
    this.authorId,
    this.savedOnly = false,
  });

  @override
  State<_VerticalClipsViewer> createState() => _VerticalClipsViewerState();
}

class _VerticalClipsViewerState extends State<_VerticalClipsViewer> {
  late final PageController _pageController;
  late List<Map<String, dynamic>> _clips;
  late int _currentIndex;
  bool _controlsVisible = true;
  bool _shortMuted = false;
  bool _moreLoading = false;
  bool _reachedEnd = false;
  Future<void> _loadMore() async {
    if (_moreLoading || _reachedEnd) return;
    _moreLoading = true;
    try {
      final data = await Supabase.instance.client.rpc('zameel_shorts_feed', params: {
        'p_author': widget.authorId,
        'p_saved': widget.savedOnly,
        'p_exclude': widget.authorId != null || widget.savedOnly ? <String>[] : _clips.map((row) => row['id'].toString()).toList().reversed.take(500).toList(),
        'p_offset': widget.authorId != null || widget.savedOnly ? _clips.length : 0,
      });
      if (!mounted) return;
      final known = _clips.map((row) => row['id'].toString()).toSet();
      final fresh = (data as List).whereType<Map>().map((row) => Map<String, dynamic>.from(row)).where((row) => !known.contains(row['id'].toString())).toList();
      setState(() { _clips.addAll(fresh); _reachedEnd = fresh.isEmpty; });
    } catch (_) {} finally { _moreLoading = false; }
  }

  final Map<String, String> _viewSessions = {};
  final Set<String> _viewPending = {};

  Future<void> _startView(int index) async {
    if (index < 0 || index >= _clips.length) return;
    final id = _clips[index]['id'].toString();
    try {
      final session = await Supabase.instance.client.rpc('zameel_shorts_start', params: {'p_clip': id});
      if (mounted) _viewSessions[id] = session.toString();
    } catch (_) {}
  }
  Future<void> _watched(Map<String, dynamic> clip, int seconds) async {
    if (seconds < 3 || (seconds != 3 && seconds != 5 && seconds % 10 != 0)) return;
    final id = clip['id'].toString(), session = _viewSessions[clip['id'].toString()];
    if (session == null || _viewPending.contains(id)) return;
    _viewPending.add(id);
    try {
      final result = await Supabase.instance.client.rpc('zameel_shorts_view', params: {'p_session': session, 'p_seconds': seconds});
      if (mounted && result is Map && result['counted'] == true) setState(() => clip['views_count'] = ((clip['views_count'] as num?)?.toInt() ?? 0) + 1);
    } catch (_) {} finally { _viewPending.remove(id); }
  }
  Future<void> _rememberMute(bool muted) async {
    _shortMuted = muted;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('zameel_shorts_muted', muted);
  }


  @override
  void initState() {
    super.initState();
    _clips = widget.clips.map(Map<String, dynamic>.from).toList();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _prefetchAround(_currentIndex);
    _startView(_currentIndex);
    if (_clips.length < 6) _loadMore();
    SharedPreferences.getInstance().then((prefs) { if (mounted) setState(() => _shortMuted = prefs.getBool('zameel_shorts_muted') ?? false); });
  }

  void _prefetchAround(int index) {
    // Current clip downloads itself. Prefetch only the next clip to avoid
    // burning egress on several full videos that may never be opened.
    final next = index + 1;
    if (next < 0 || next >= _clips.length) return;
    final url = _clips[next]['video_url']?.toString() ?? '';
    if (url.isNotEmpty) {
      // Signing is lightweight; prefetching an entire video competes with
      // the one the user is watching on a weak connection.
      unawaited(SecureMediaService.resolve(url).then<void>((_) {}, onError: (Object _) {}));
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _shortAction(String action, Map<String, dynamic> clip, bool ar) async {
    final db = Supabase.instance.client;
    try {
      if (action == 'report') {
        await showContentReportDialog(context, clip['id'].toString(), 'clip', ar);
        return;
      }
      if (action == 'delete') {
        await _delete(clip);
        return;
      }
      if (action == 'block') {
        final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text(ar ? 'حظر الحساب؟' : 'Block account?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ar ? 'إلغاء' : 'Cancel')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ar ? 'حظر' : 'Block'))]));
        if (confirm != true) return;
        await db.from('user_blocks').upsert({'blocker_id': db.auth.currentUser!.id, 'blocked_id': clip['user_id']});
      } else {
        await db.rpc('zameel_shorts_preference', params: {'p_clip': clip['id'], 'p_action': action});
        if (mounted && (action == 'save' || action == 'unsave')) setState(() => clip['saved'] = action == 'save');
      }
      if (action == 'hide' || action == 'block') {
        final actor = db.auth.currentUser?.id;
        if (actor != null) await HomeSnapshotService.clear(actor, section: 'clips');
        if (mounted) Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ar ? 'تعذر تنفيذ الإجراء' : 'Could not complete action')));
    }
  }

  Future<void> _delete(Map<String, dynamic> clip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الشورتس؟'),
        content: const Text(
          'سيتم حذف هذا الشورتس نهائيًا من جميع أماكن ظهوره.',
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
      setState(() {
        _clips.removeWhere((item) => item['id']?.toString() == clip['id']?.toString());
        if (_clips.isNotEmpty) _currentIndex = _currentIndex.clamp(0, _clips.length - 1).toInt();
      });
      if (_clips.isEmpty) {
        Navigator.pop(context);
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pageController.hasClients) { _pageController.jumpToPage(_currentIndex); _startView(_currentIndex); }
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(FeatureControl.errorMessage(error, 'تعذر حذف الشورتس'))),
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
    if (!await FeatureControl.instance.check(context, 'comments')) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FeatureControl.instance.page('comments', ClipCommentsScreen(clip: clip))),
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
    final ar = Provider.of<LanguageProvider>(context).isArabic;
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
          _startView(index);
          if (index >= _clips.length - 5) _loadMore();
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
                          key: ValueKey(clip['id']),
                          videoUrl: clip['video_url']?.toString() ?? '',
                          initialMuted: _shortMuted,
                          tapToPause: true,
                          onMuteChanged: _rememberMute,
                          onWatchedSeconds: (seconds) => _watched(clip, seconds),
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
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_horiz, color: Colors.white),
                            onSelected: (action) => _shortAction(action, clip, ar),
                            itemBuilder: (_) => [
                              PopupMenuItem(value: clip['saved'] == true ? 'unsave' : 'save', child: Text(clip['saved'] == true ? (ar ? 'إلغاء الحفظ' : 'Unsave') : (ar ? 'حفظ' : 'Save'))),
                              if (!mine) ...[
                                PopupMenuItem(value: 'report', child: Text(ar ? 'إبلاغ' : 'Report')),
                                PopupMenuItem(value: 'hide', child: Text(ar ? 'لا تعرض هذا المقطع مجددًا' : 'Do not show this Short again')),
                                PopupMenuItem(value: 'block', child: Text(ar ? 'حظر الحساب' : 'Block account')),
                              ],
                              if (mine) PopupMenuItem(value: 'delete', child: Text(ar ? 'حذف' : 'Delete')),
                            ],
                          ),
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
                        Text(ar ? '${clip['views_count'] ?? 0} مشاهدة' : '${clip['views_count'] ?? 0} views', style: const TextStyle(color: Colors.white70)),
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
                              label: Text(ar ? 'مشاركة' : 'Share'),
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
  int _generation = 0;
  @override
  void initState() { super.initState(); _prepare(); }
  @override
  void didUpdateWidget(covariant _ClipAutoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (MediaCacheService.identity(oldWidget.url) != MediaCacheService.identity(widget.url) ||
        oldWidget.autoplay != widget.autoplay) {
      _generation++;
      _timer?.cancel();
      _controller?.dispose();
      _controller = null;
      _prepare();
    }
  }
  Future<void> _prepare() async {
    if (widget.url.isEmpty || !widget.autoplay) return;
    final generation = ++_generation;
    try {
      final c = await VideoSourceService.controller(widget.url);
      if (!mounted || generation != _generation) { await c.dispose(); return; }
      _controller = c;
      await c.initialize();
      if (!mounted || generation != _generation) return;
      await c.setVolume(0);
      await c.play();
      if (!mounted || generation != _generation) return;
      _timer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted && generation == _generation) c.pause();
      });
      setState(() {});
    } catch (_) {}
  }
  @override
  void dispose() { _generation++; _timer?.cancel(); _controller?.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const ColoredBox(color: Colors.black87,
        child: Icon(Icons.video_library_outlined, color: Colors.white54));
    }
    return FittedBox(fit: BoxFit.cover, child: SizedBox(width: c.value.size.width,
      height: c.value.size.height, child: VideoPlayer(c)));
  }
}

Future<void> openShortsViewer(BuildContext context, List<Map<String, dynamic>> clips, int index, {String? authorId, bool savedOnly = false}) async {
 if (clips.isEmpty || index < 0 || index >= clips.length) return;
 await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => FeatureControl.instance.page('clips', _VerticalClipsViewer(clips: clips, initialIndex: index, authorId: authorId, savedOnly: savedOnly))));
}
