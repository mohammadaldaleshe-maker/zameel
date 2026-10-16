import '../services/media_cache_service.dart';
import '../services/media_dimensions163.dart';
import '../main.dart' show MixedPostMediaViewer;
import 'package:zameel/theme/appearance_controller.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'cached_media_image.dart';
import 'video_player_widget.dart';

class PostMediaItem {
  final String type;
  final String url;
  final String? name;

  const PostMediaItem({
    required this.type,
    required this.url,
    this.name,
  });

  bool get isVideo => type == 'video';
}

/// Reads the new ordered media list first, then falls back to the legacy
/// image_url/video_url columns. This keeps every old post rendering exactly
/// through the same data it already had before migration 066.
List<PostMediaItem> postMediaItems(Map<String, dynamic> post) {
  final result = <PostMediaItem>[];
  final raw = post['media_items'];

  if (raw is List) {
    for (final value in raw) {
      if (value is! Map) continue;
      final map = Map<String, dynamic>.from(value);
      final url = map['url']?.toString().trim() ?? '';
      final type = map['type']?.toString().trim().toLowerCase() ?? '';
      if (url.isEmpty || (type != 'image' && type != 'video')) continue;
      result.add(
        PostMediaItem(
          type: type,
          url: url,
          name: map['name']?.toString(),
        ),
      );
    }
  }

  if (result.isNotEmpty) return result;

  final imageUrl = post['image_url']?.toString().trim() ?? '';
  final videoUrl = post['video_url']?.toString().trim() ?? '';
  if (imageUrl.isNotEmpty) {
    result.add(PostMediaItem(type: 'image', url: imageUrl));
  }
  if (videoUrl.isNotEmpty) {
    result.add(PostMediaItem(type: 'video', url: videoUrl));
  }
  return result;
}

class PostMediaGallery extends StatefulWidget {
  final Map<String, dynamic> post;
  final double height;
  final BorderRadius borderRadius;
  final VoidCallback? onLikeChanged;
  final void Function(PostMediaItem item, int index)? onOpen;

  const PostMediaGallery({
    super.key,
    required this.post,
    this.height = 260,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.onOpen,
    this.onLikeChanged,
  });

  @override
  State<PostMediaGallery> createState() => _PostMediaGalleryState();
}

class _PostMediaGalleryState extends State<PostMediaGallery> {
  final PageController _controller = PageController();
  int _index = 0;
  final Map<String, double> _ratios = {};
  final Map<String, double> _pendingRatios = {};
  final Set<String> _requested = {};
  ScrollPosition? _position;

  @override
  void initState() {
    super.initState();
    _loadRatios();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _position) {
      _position?.isScrollingNotifier.removeListener(_applyRatios);
      _position = position;
      _position?.isScrollingNotifier.addListener(_applyRatios);
    }
  }

  @override
  void didUpdateWidget(covariant PostMediaGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    final items = postMediaItems(widget.post);
    if (_index >= items.length || oldWidget.post['id'] != widget.post['id']) {
      _index = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) _controller.jumpToPage(0);
      });
    }
    _loadRatios();
  }

  void _loadRatios() {
    for (final item in postMediaItems(widget.post)) {
      final identity = MediaCacheService.identity(item.url);
      if (item.isVideo || !_requested.add(identity)) continue;
      mediaAspectRatio163(item.url)
          .timeout(const Duration(seconds: 15))
          .then((ratio) {
        if (!mounted || ratio == null || !ratio.isFinite || ratio <= 0) return;
        _pendingRatios[identity] = ratio;
        _applyRatios();
      }).catchError((Object _) {});
    }
  }

  void _applyRatios() {
    if (!mounted ||
        _pendingRatios.isEmpty ||
        (_position?.isScrollingNotifier.value ?? false)) return;
    final box = context.findRenderObject();
    final oldHeight = box is RenderBox && box.hasSize ? box.size.height : 0.0;
    final above = box is RenderBox &&
        box.hasSize &&
        box.localToGlobal(Offset.zero).dy + box.size.height <= 0;
    setState(() {
      _ratios.addAll(_pendingRatios);
      _pendingRatios.clear();
    });
    // A completed legacy image above the viewport must not move the reader.
    if (above && _position != null)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            _position == null ||
            _position!.isScrollingNotifier.value) return;
        final box = context.findRenderObject();
        if (box is RenderBox && box.hasSize) {
          _position!.jumpTo((_position!.pixels + box.size.height - oldHeight)
              .clamp(_position!.minScrollExtent, _position!.maxScrollExtent));
        }
      });
  }

  @override
  void dispose() {
    _position?.isScrollingNotifier.removeListener(_applyRatios);
    _controller.dispose();
    super.dispose();
  }

  void _openDefault(List<PostMediaItem> items, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MixedPostMediaViewer(
            post: widget.post,
            initialIndex: index,
            onLikeChanged: widget.onLikeChanged),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppearanceScope.observe(context);
    final items = postMediaItems(widget.post);
    if (items.isEmpty) return const SizedBox.shrink();

    final item = items[_index.clamp(0, items.length - 1)];
    double? ratio = _ratios[MediaCacheService.identity(item.url)];
    final media = widget.post['media_items'];
    if (media is List && _index < media.length && media[_index] is Map) {
      final raw = media[_index] as Map;
      final width = num.tryParse('${raw['width']}');
      final height = num.tryParse('${raw['height']}');
      if (width != null && height != null && width > 0 && height > 0)
        ratio = width / height;
    }
    return LayoutBuilder(
        builder: (context, constraints) => Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                  borderRadius: widget.borderRadius,
                  border: Border.all(
                      color: AppTheme.adaptiveGlassBorder, width: 1.5)),
              child: SizedBox(
                height: !item.isVideo &&
                        ratio != null &&
                        constraints.maxWidth.isFinite
                    ? (constraints.maxWidth - 3) / ratio + 3
                    : widget.height,
                child: Stack(
                  children: [
                    PageView.builder(
                      controller: _controller,
                      itemCount: items.length,
                      onPageChanged: (value) => setState(() => _index = value),
                      itemBuilder: (_, index) {
                        final item = items[index];
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              if (widget.onOpen != null) {
                                widget.onOpen!(item, index);
                              } else {
                                _openDefault(items, index);
                              }
                            },
                            child: item.isVideo
                                ? Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      VideoPlayerWidget(
                                        key: ValueKey(item.url),
                                        videoUrl: item.url,
                                      ),
                                      PositionedDirectional(
                                        end: 8,
                                        top: 8,
                                        child: DecoratedBox(
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: IconButton(
                                            tooltip:
                                                'فتح الفيديو بالحجم الكامل',
                                            icon: const Icon(Icons.fullscreen,
                                                color: Colors.white),
                                            onPressed: () {
                                              if (widget.onOpen != null) {
                                                widget.onOpen!(item, index);
                                              } else {
                                                _openDefault(items, index);
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : CachedMediaImage(
                                    url: item.url,
                                    fit: BoxFit.contain,
                                    fallback: Container(
                                      alignment: Alignment.center,
                                      color: AppTheme.adaptiveSurfaceAlt,
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        color: AppTheme.adaptiveSecondary,
                                        size: 50,
                                      ),
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
                    if (items.length > 1)
                      PositionedDirectional(
                        top: 10,
                        end: 10,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xA8000000),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            child: Text(
                              '${_index + 1}/${items.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (items.length > 1)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 8,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            items.length,
                            (i) => AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: i == _index ? 18 : 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color:
                                    i == _index ? Colors.white : Colors.white54,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ));
  }
}
