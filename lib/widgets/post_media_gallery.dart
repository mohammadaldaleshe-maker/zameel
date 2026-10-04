import '../main.dart' show MixedPostMediaViewer;
import 'package:zameel/theme/appearance_controller.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'cached_media_image.dart';

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

  @override
  void dispose() {
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

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          border: Border.all(color: AppTheme.adaptiveGlassBorder, width: 1.5)),
      child: SizedBox(
        height: widget.height,
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
                              Container(color: Colors.black),
                              Center(
                                child: Icon(
                                  Icons.play_circle_fill_rounded,
                                  color: Colors.white,
                                  size: 70,
                                ),
                              ),
                              PositionedDirectional(
                                start: 12,
                                bottom: 12,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.videocam_rounded,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        SizedBox(width: 5),
                                        Text(
                                          'Video',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
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
                        color: i == _index ? Colors.white : Colors.white54,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
