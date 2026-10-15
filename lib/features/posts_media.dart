part of '../main.dart';

int _actionCount161(dynamic value) => value is num
    ? value.toInt().clamp(0, 2147483647)
    : (int.tryParse('$value') ?? 0).clamp(0, 2147483647);

bool _hasOrderedPostMedia(Map<String, dynamic> post) {
  final raw = post['media_items'];
  return raw is List && raw.isNotEmpty;
}

void _openOrderedPostMedia(
    BuildContext context, Map<String, dynamic> post, PostMediaItem item,
    {VoidCallback? onLikeChanged}) {
  final items = postMediaItems(post);
  final index =
      items.indexWhere((x) => x.url == item.url && x.type == item.type);
  Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => MixedPostMediaViewer(
              post: post,
              initialIndex: index < 0 ? 0 : index,
              onLikeChanged: onLikeChanged)));
}

class MixedPostMediaViewer extends StatefulWidget {
  const MixedPostMediaViewer(
      {super.key,
      required this.post,
      required this.initialIndex,
      this.onLikeChanged});
  final Map<String, dynamic> post;
  final int initialIndex;
  final VoidCallback? onLikeChanged;
  @override
  State<MixedPostMediaViewer> createState() => _MixedPostMediaViewerState();
}

class _MixedPostMediaViewerState extends State<MixedPostMediaViewer> {
  late int _index;
  Offset? _down;
  int _pointers = 0;
  bool _multi = false;
  bool _zoomed = false;
  late List<PostMediaItem> _items;
  @override
  void initState() {
    super.initState();
    _items = postMediaItems(widget.post);
    _index = widget.initialIndex
        .clamp(0, (_items.length - 1).clamp(0, _items.length))
        .toInt();
  }

  void _move(int delta) {
    final next = _index + delta;
    if (next >= 0 && next < _items.length)
      setState(() {
        _index = next;
        _zoomed = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty)
      return const Scaffold(body: Center(child: Text('لا توجد وسائط')));
    final item = _items[_index];
    if (_items.length == 1 && item.isVideo) {
      widget.post['video_url'] = item.url;
      return ZameelMediaViewer(
          post: widget.post,
          isVideo: true,
          onLikeChanged: widget.onLikeChanged);
    }
    final selected = {
      ...widget.post,
      'type': item.type,
      'image_url': item.isVideo ? null : item.url,
      'video_url': item.isVideo ? item.url : null,
      'media_index': _index
    };
    return Listener(
      onPointerDown: (event) {
        _pointers++;
        if (_pointers == 1) {
          _down = event.position;
          _multi = false;
        } else {
          _multi = true;
        }
      },
      onPointerCancel: (_) {
        _pointers = 0;
        _down = null;
      },
      onPointerUp: (event) {
        _pointers = (_pointers - 1).clamp(0, 10).toInt();
        if (_pointers != 0 || _multi || _zoomed || _down == null) return;
        final delta = event.position - _down!;
        _down = null;
        if (item.isVideo &&
            delta.dy.abs() > 80 &&
            delta.dy.abs() > delta.dx.abs()) _move(delta.dy < 0 ? 1 : -1);
        if (!item.isVideo &&
            delta.dx.abs() > 80 &&
            delta.dx.abs() > delta.dy.abs()) _move(delta.dx > 0 ? 1 : -1);
      },
      child: Stack(children: [
        ZameelMediaViewer(
            key: ValueKey('media_$_index'),
            post: selected,
            isVideo: item.isVideo,
            enableVerticalPaging: false,
            autoplayVideo: item.isVideo,
            onZoomChanged: (zoomed) => _zoomed = zoomed,
            onVideoCompleted: () => _move(1),
            onLikeChanged: () {
              for (final key in [
                'liked',
                'likes',
                'likes_count',
                'comments',
                'comments_count',
                'isSaved'
              ]) {
                if (selected.containsKey(key)) widget.post[key] = selected[key];
              }
              widget.onLikeChanged?.call();
            }),
        Positioned(
            top: MediaQuery.paddingOf(context).top + 58,
            right: 8,
            child: Material(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                      onPressed: _index > 0 ? () => _move(-1) : null,
                      icon:
                          const Icon(Icons.chevron_left, color: Colors.white)),
                  Text('${_index + 1}/${_items.length}',
                      style: const TextStyle(color: Colors.white)),
                  IconButton(
                      onPressed:
                          _index < _items.length - 1 ? () => _move(1) : null,
                      icon:
                          const Icon(Icons.chevron_right, color: Colors.white)),
                ]))),
      ]),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback onLike;
  final List<Map<String, dynamic>> savedPosts;
  final bool isAdmin;
  final String? postOwnerId;
  final VoidCallback onDelete;
  final Future<void> Function(Map<String, dynamic>)? onShareToProfile;

  const _PostCard({
    required this.post,
    required this.onLike,
    required this.savedPosts,
    this.isAdmin = false,
    this.postOwnerId,
    required this.onDelete,
    this.onShareToProfile,
  });

  @override
  Widget build(BuildContext context) {
    AppearanceScope.observe(context);
    final String type = post['type'] ?? 'text';

    Widget withMentions(Widget child) => child;
    if (type == 'video') {
      return withMentions(_VideoPost(
        post: post,
        onLike: onLike,
        savedPosts: savedPosts,
        isAdmin: isAdmin,
        postOwnerId: postOwnerId,
        onDelete: onDelete,
        onShareToProfile: onShareToProfile,
      ));
    }

    if (type == 'image') {
      return withMentions(_ImagePost(
        post: post,
        onLike: onLike,
        savedPosts: savedPosts,
        isAdmin: isAdmin,
        postOwnerId: postOwnerId,
        onDelete: onDelete,
        onShareToProfile: onShareToProfile,
      ));
    }

    return withMentions(_TextPost(
      post: post,
      onLike: onLike,
      savedPosts: savedPosts,
      isAdmin: isAdmin,
      postOwnerId: postOwnerId,
      onDelete: onDelete,
      onShareToProfile: onShareToProfile,
    ));
  }
}

// ============================================================
// IMAGE POST
// ============================================================

class _ImagePost extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback onLike;
  final List<Map<String, dynamic>> savedPosts;
  final bool isAdmin;
  final String? postOwnerId;
  final VoidCallback onDelete;
  final Future<void> Function(Map<String, dynamic>)? onShareToProfile;

  const _ImagePost({
    required this.post,
    required this.onLike,
    required this.savedPosts,
    this.isAdmin = false,
    this.postOwnerId,
    required this.onDelete,
    this.onShareToProfile,
  });

  @override
  State<_ImagePost> createState() => _ImagePostState();
}

class _ImagePostState extends State<_ImagePost> {
  late bool _isOwner;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    _isOwner = widget.post['user_id'] == user?.id;
  }

  @override
  Widget build(BuildContext context) {
    AppearanceScope.observe(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    final bool liked = widget.post['liked'] ?? false;
    final bool isSaved = widget.post['isSaved'] ?? false;
    final String imageUrl = widget.post['image_url']?.toString() ?? '';
    final bool hasOrderedMedia = _hasOrderedPostMedia(widget.post);
    final bool canDelete = widget.isAdmin || _isOwner;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ------------------------------------------------------
        // HEADER
        // ------------------------------------------------------
        Row(
          children: [
            GestureDetector(
              onTap: () => _openUserProfile(
                context,
                widget.post['user_id']?.toString(),
              ),
              child: _PostOwnerAvatar(
                  imageUrl: widget.post['profile_image']?.toString(),
                  radius: 18.7),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openUserProfile(
                  context,
                  widget.post['user_id']?.toString(),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                          child: VerifiedName(
                              userId: widget.post['user_id']?.toString(),
                              child: Text(
                                isArabic
                                    ? (widget.post['name_ar'] ?? 'مستخدم')
                                        .toString()
                                    : (widget.post['name_en'] ?? 'User')
                                        .toString(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppTheme.legacyForeground,
                                ),
                              ))),
                      const SizedBox.shrink()
                    ]),
                    const SizedBox(height: 3),
                    Text(
                      postMetadata157(widget.post, isArabic),
                      style: TextStyle(
                        color: AppTheme.legacySecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // --------------------------------------------------
            // MORE / DELETE
            // --------------------------------------------------
            PostReportMenu(
              onEdited: (row) {
                if (mounted) setState(() => widget.post.addAll(row));
              },
              post: widget.post,
              postId: widget.post['id']?.toString() ?? '',
              authorId: widget.post['user_id']?.toString(),
              ar: isArabic,
              canDelete: canDelete,
              onDelete: widget.onDelete,
            ),
          ],
        ),
        const SizedBox(height: 12),
        // ------------------------------------------------------
        // TEXT
        // ------------------------------------------------------
        if (((isArabic ? widget.post['text_ar'] : widget.post['text_en']) ?? '')
            .toString()
            .trim()
            .isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: MentionContent158(
              (isArabic ? widget.post['text_ar'] : widget.post['text_en'])
                  .toString(),
              kind: 'post',
              id: '${widget.post['id']}',
              header: true,
              style: TextStyle(
                color: AppTheme.legacyForeground,
                fontSize: 16,
                height: 1.6,
              ),
            ),
          ),
        // ------------------------------------------------------
        // IMAGE
        // ------------------------------------------------------
        if (hasOrderedMedia)
          PostMediaGallery(
            post: widget.post,
            height: postMediaHeight(context),
            onOpen: (item, _) => _openOrderedPostMedia(
              context,
              widget.post,
              item,
              onLikeChanged: () {
                if (mounted) setState(() {});
              },
            ),
          )
        else if (imageUrl.isNotEmpty)
          PostMediaFrame(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ZameelMediaViewer(
                      post: widget.post,
                      isVideo: false,
                      onLikeChanged: () => setState(() {}),
                    ),
                  ),
                );
              },
              child: SizedBox(
                width: double.infinity,
                child: CachedMediaImage(
                  url: imageUrl,
                  fit: BoxFit.contain,
                  fallback: Container(
                    alignment: Alignment.center,
                    color: Colors.white10,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: AppTheme.legacySecondary,
                      size: 50,
                    ),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        // ------------------------------------------------------
        // COUNTERS
        // ------------------------------------------------------
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // LIKE
            _PostAction(
              count: _actionCount161(
                  widget.post['likes'] ?? widget.post['likes_count']),
              icon: liked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              text: isArabic ? 'إعجاب' : 'Like',
              onCountTap: () =>
                  _showPostLikesDialog(context, widget.post, isArabic),
              active: liked,
              onTap: widget.onLike,
              color: AppTheme.legacySecondary,
            ),
            // COMMENTS
            _PostAction(
              count: _actionCount161(
                  widget.post['comments'] ?? widget.post['comments_count']),
              icon: Icons.comment_outlined,
              text: Translations.translate(
                'comments_title',
                languageProvider.currentLanguage,
              ),
              onTap: () async {
                if (!await FeatureControl.instance.check(context, 'comments'))
                  return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FeatureControl.instance.page(
                        'comments',
                        CommentsScreen(
                          post: widget.post,
                        )),
                  ),
                );
              },
              color: AppTheme.legacySecondary,
            ),
            // SAVE
            if (FeatureControl.instance.visible('saved_posts'))
              _PostAction(
                icon: isSaved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                text: isArabic ? 'حفظ' : 'Save',
                active: isSaved,
                color: isSaved ? accentColor : AppTheme.legacySecondary,
                onTap: () {
                  setState(() {
                    widget.post['isSaved'] = !isSaved;
                    if (widget.post['isSaved'] == true) {
                      widget.savedPosts.insert(
                        0,
                        widget.post,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isArabic ? 'تم حفظ المنشور' : 'Post saved',
                          ),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    } else {
                      widget.savedPosts.removeWhere(
                        (p) =>
                            p['id'] == widget.post['id'] ||
                            p['text'] == widget.post['text'],
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isArabic
                                ? 'تم إلغاء حفظ المنشور'
                                : 'Post removed from saved',
                          ),
                          backgroundColor: Colors.orange,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                  });
                },
              ),
            // SHARE
            _PostAction(
              count: _actionCount161(
                  widget.post['shares'] ?? widget.post['shares_count']),
              icon: Icons.share_outlined,
              text: isArabic ? 'مشاركة' : 'Share',
              color: AppTheme.legacySecondary,
              onTap: () => showContentShare157(context,
                  id: '${widget.post['id']}', onProfile: () async {
                if (widget.onShareToProfile != null) {
                  await widget.onShareToProfile!(widget.post);
                }
              }),
            ),
          ],
        ),
        Divider(color: AppTheme.adaptiveGlassBorder, height: 20),
      ],
    );
  }
}

// ============================================================
// VIDEO POST
// ============================================================

class _VideoPost extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback onLike;
  final List<Map<String, dynamic>> savedPosts;
  final bool isAdmin;
  final String? postOwnerId;
  final VoidCallback onDelete;
  final Future<void> Function(Map<String, dynamic>)? onShareToProfile;

  const _VideoPost({
    required this.post,
    required this.onLike,
    required this.savedPosts,
    this.isAdmin = false,
    this.postOwnerId,
    required this.onDelete,
    this.onShareToProfile,
  });

  @override
  State<_VideoPost> createState() => _VideoPostState();
}

class _VideoPostState extends State<_VideoPost> {
  @override
  Widget build(BuildContext context) {
    AppearanceScope.observe(context);
    final bool liked = widget.post['liked'] ?? false;
    final String videoUrl = postVideoReference156(widget.post);
    final bool hasOrderedMedia = _hasOrderedPostMedia(widget.post) &&
        postMediaItems(widget.post).isNotEmpty;
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => _openUserProfile(
                context,
                widget.post['user_id']?.toString(),
              ),
              child: _PostOwnerAvatar(
                  imageUrl: widget.post['profile_image']?.toString(),
                  radius: 18.7),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openUserProfile(
                  context,
                  widget.post['user_id']?.toString(),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                          child: VerifiedName(
                              userId: widget.post['user_id']?.toString(),
                              child: Text(
                                isArabic
                                    ? widget.post['name_ar']
                                    : widget.post['name_en'],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppTheme.legacyForeground,
                                ),
                              ))),
                      const SizedBox.shrink()
                    ]),
                    const SizedBox(height: 3),
                    Text(
                      postMetadata157(widget.post, isArabic),
                      style: TextStyle(
                        color: AppTheme.legacySecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            PostReportMenu(
              onEdited: (row) {
                if (mounted) setState(() => widget.post.addAll(row));
              },
              post: widget.post,
              postId: widget.post['id']?.toString() ?? '',
              authorId: widget.post['user_id']?.toString(),
              ar: isArabic,
              canDelete: widget.isAdmin ||
                  widget.post['user_id']?.toString() ==
                      Supabase.instance.client.auth.currentUser?.id,
              onDelete: widget.onDelete,
            ),
          ],
        ),
        const SizedBox(height: 10),
        MentionContent158(
          isArabic ? widget.post['text_ar'] : widget.post['text_en'],
          kind: 'post',
          id: '${widget.post['id']}',
          header: true,
          style: TextStyle(
            color: AppTheme.legacyForeground,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        if (hasOrderedMedia)
          PostMediaGallery(
            post: widget.post,
            height: postMediaHeight(context),
            onOpen: (item, _) => _openOrderedPostMedia(
              context,
              widget.post,
              item,
              onLikeChanged: () {
                if (mounted) setState(() {});
              },
            ),
          )
        else
          PostMediaFrame(
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ZameelMediaViewer(
                    post: widget.post,
                    isVideo: true,
                    onLikeChanged: () => setState(() {}),
                  ),
                ),
              ),
              child: SizedBox(
                height: postMediaHeight(context),
                width: double.infinity,
                child: videoUrl.isEmpty
                    ? Center(
                        child: Text(
                            isArabic
                                ? 'تعذر عرض الفيديو الأصلي'
                                : 'Original video unavailable',
                            style: TextStyle(color: AppTheme.legacyForeground),
                            textAlign: TextAlign.center))
                    : VideoPlayerWidget(videoUrl: videoUrl),
              ),
            ),
          ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _PostAction(
              count: _actionCount161(
                  widget.post['likes'] ?? widget.post['likes_count']),
              icon: liked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              text: isArabic ? 'إعجاب' : 'Like',
              onCountTap: () =>
                  _showPostLikesDialog(context, widget.post, isArabic),
              active: liked,
              onTap: widget.onLike,
              color: AppTheme.legacySecondary,
            ),
            _PostAction(
              count: _actionCount161(
                  widget.post['comments'] ?? widget.post['comments_count']),
              icon: Icons.comment_rounded,
              text: '${widget.post['comments']}',
              onTap: () async {
                if (!await FeatureControl.instance.check(context, 'comments'))
                  return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FeatureControl.instance.page(
                        'comments',
                        CommentsScreen(
                          post: widget.post,
                        )),
                  ),
                );
              },
              color: AppTheme.legacySecondary,
            ),
            if (FeatureControl.instance.visible('saved_posts'))
              _PostAction(
                icon: widget.post['isSaved'] == true
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                text: isArabic ? 'حفظ' : 'Save',
                color: widget.post['isSaved'] == true
                    ? accentColor
                    : AppTheme.legacySecondary,
                onTap: () {
                  setState(() {
                    widget.post['isSaved'] = !(widget.post['isSaved'] == true);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        widget.post['isSaved'] == true
                            ? (isArabic ? '✅ تم حفظ الفيديو' : '✅ Video saved')
                            : (isArabic
                                ? '🗑️ تم إلغاء حفظ الفيديو'
                                : '🗑️ Video removed from saved'),
                      ),
                      backgroundColor: AppTheme.primary,
                    ),
                  );
                },
              ),
            _PostAction(
              count: _actionCount161(
                  widget.post['shares'] ?? widget.post['shares_count']),
              icon: Icons.share_rounded,
              text: isArabic ? 'مشاركة' : 'Share',
              color: AppTheme.legacySecondary,
              onTap: () => showContentShare157(context,
                  id: '${widget.post['id']}', onProfile: () async {
                if (widget.onShareToProfile != null) {
                  await widget.onShareToProfile!(widget.post);
                }
              }),
            ),
          ],
        ),
        Divider(color: AppTheme.adaptiveGlassBorder, height: 20),
      ],
    );
  }
}

Future<void> _showPostLikesDialog(
    BuildContext context, Map<String, dynamic> post, bool isArabic) async {
  final postId = post['id'];
  if (postId == null) return;
  try {
    final rows = await Supabase.instance.client
        .from('likes')
        .select('user_id, users(name, profile_image)')
        .eq('post_id', postId)
        .order('created_at', ascending: false);
    if (!context.mounted) return;
    showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (_) => Directionality(
            textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
            child: SizedBox(
                height: 480,
                child: Column(children: [
                  Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                          isArabic
                              ? 'الأشخاص الذين أعجبوا بالمنشور'
                              : 'People who liked this post',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800))),
                  Expanded(
                      child: rows.isEmpty
                          ? Center(
                              child: Text(isArabic
                                  ? 'لا توجد إعجابات بعد'
                                  : 'No likes yet'))
                          : ListView.builder(
                              itemCount: rows.length,
                              itemBuilder: (_, i) {
                                final u = rows[i]['users'];
                                final name = u is Map
                                    ? (u['name']?.toString() ?? 'User')
                                    : 'User';
                                final image = u is Map
                                    ? u['profile_image']?.toString()
                                    : null;
                                return ListTile(
                                    leading: CircleAvatar(
                                        backgroundImage:
                                            image != null && image.isNotEmpty
                                                ? NetworkImage(image)
                                                : null,
                                        child: image == null || image.isEmpty
                                            ? const Icon(Icons.person)
                                            : null),
                                    title: VerifiedName(
                                        userId: rows[i]['user_id']?.toString(),
                                        child: Text(name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700))));
                              }))
                ]))));
  } catch (e) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              FeatureControl.errorMessage(e, 'تعذر تحميل قائمة الإعجابات'))));
  }
}

// ============================================================
// MEDIA VIEWER
// ============================================================

class ZameelMediaViewer extends StatefulWidget {
  final Map<String, dynamic> post;
  final bool isVideo;
  final VoidCallback? onLikeChanged;
  final bool enableVerticalPaging;
  final VoidCallback? onVideoCompleted;
  final bool autoplayVideo;
  final bool videoActive;
  final ValueChanged<bool>? onZoomChanged;

  const ZameelMediaViewer({
    super.key,
    required this.post,
    required this.isVideo,
    this.onLikeChanged,
    this.enableVerticalPaging = true,
    this.onVideoCompleted,
    this.autoplayVideo = false,
    this.videoActive = true,
    this.onZoomChanged,
  });

  @override
  State<ZameelMediaViewer> createState() => _ZameelMediaViewerState();
}

class _ZameelMediaViewerState extends State<ZameelMediaViewer> {
  bool _busy = false;
  bool _sendingComment = false;
  bool _controlsVisible = true;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocus = FocusNode();
  final TransformationController _imageTransform = TransformationController();

  String get _url => widget.isVideo
      ? postVideoReference156(widget.post)
      : (widget.post['image_url'] ?? widget.post['imageUrl'])?.toString() ?? '';

  int _count(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  void dispose() {
    _imageTransform.dispose();
    _commentController.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    if (_busy) return;
    final user = Supabase.instance.client.auth.currentUser;
    final postId = widget.post['id'];
    final liked = widget.post['liked'] == true;
    final oldCount = _count(widget.post['likes_count'] ?? widget.post['likes']);

    if (user == null || postId == null || widget.post['is_demo'] == true) {
      setState(() {
        widget.post['liked'] = !liked;
        widget.post['likes_count'] =
            liked ? (oldCount > 0 ? oldCount - 1 : 0) : oldCount + 1;
        widget.post['likes'] = widget.post['likes_count'];
      });
      widget.onLikeChanged?.call();
      return;
    }

    setState(() => _busy = true);
    try {
      final result = await setPostLike161(Supabase.instance.client,
          userId: user.id, postId: '$postId', liked: !liked);
      if (!mounted) return;
      setState(() {
        widget.post['liked'] = !liked;
        widget.post['likes_count'] =
            result.displayCount(oldCount, liked: !liked);
        widget.post['likes'] = widget.post['likes_count'];
      });
      widget.onLikeChanged?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(FeatureControl.errorMessage(e, 'تعذر تحديث الإعجاب'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleSave() async {
    if (!await FeatureControl.instance.check(context, 'saved_posts')) return;
    final user = Supabase.instance.client.auth.currentUser;
    final postId = widget.post['id'];
    if (_busy) return;
    final saved = widget.post['isSaved'] == true;

    if (user == null || postId == null || widget.post['is_demo'] == true) {
      setState(() => widget.post['isSaved'] = !saved);
      return;
    }

    setState(() => _busy = true);
    try {
      if (saved) {
        await Supabase.instance.client
            .from('saved_posts')
            .delete()
            .eq('user_id', user.id)
            .eq('post_id', postId);
      } else {
        await Supabase.instance.client
            .from('saved_posts')
            .upsert({'user_id': user.id, 'post_id': postId});
      }
      if (mounted) setState(() => widget.post['isSaved'] = !saved);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(FeatureControl.errorMessage(e, 'تعذر تحديث الحفظ'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    final user = Supabase.instance.client.auth.currentUser;
    final postId = widget.post['id']?.toString();
    if (postId == null || user == null || widget.post['is_demo'] == true)
      return;
    await showContentShare157(context, id: postId, onProfile: () async {
      await Supabase.instance.client.from('shared_posts').upsert(
          {'post_id': postId, 'shared_by': user.id},
          onConflict: 'post_id,shared_by');
      SharedActivity156.refresh();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تمت المشاركة على صفحتك الشخصية')));
    });
  }

  Future<void> _addComment(bool isArabic) async {
    if (!await FeatureControl.instance.check(context, 'comments')) return;
    final text = _commentController.text.trim();
    final user = Supabase.instance.client.auth.currentUser;
    final postId = widget.post['id'];
    if (text.isEmpty || _sendingComment) return;
    if (user == null || postId == null || widget.post['is_demo'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic
                  ? 'يجب تسجيل الدخول وعلى منشور حقيقي لإضافة تعليق.'
                  : 'Sign in and open a published post to add a comment.',
            ),
          ),
        );
      }
      return;
    }

    setState(() => _sendingComment = true);
    try {
      await Supabase.instance.client.from('post_comments').insert({
        'post_id': postId,
        'user_id': user.id,
        'content': text,
      });
      _commentController.clear();
      final currentComments =
          _count(widget.post['comments_count'] ?? widget.post['comments']);
      if (!mounted) return;
      setState(() {
        widget.post['comments_count'] = currentComments + 1;
        widget.post['comments'] = currentComments + 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(isArabic ? 'تم إضافة التعليق ✓' : 'Comment added ✓')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(FeatureControl.errorMessage(
                e, isArabic ? 'تعذر إضافة التعليق' : 'Could not add comment')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  Future<void> _openComments() async {
    if (!await FeatureControl.instance.check(context, 'comments')) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => FeatureControl.instance
              .page('comments', CommentsScreen(post: widget.post))),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    AppearanceScope.observe(context);
    if (widget.isVideo && widget.enableVerticalPaging) {
      return _VerticalPostVideoViewer(
          initialPost: widget.post, onLikeChanged: widget.onLikeChanged);
    }
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;
    final liked = widget.post['liked'] == true;
    final saved = widget.post['isSaved'] == true;
    final text = (isArabic
                ? (widget.post['text_ar'] ?? widget.post['text_en'])
                : (widget.post['text_en'] ?? widget.post['text_ar']))
            ?.toString() ??
        '';
    final comments =
        _count(widget.post['comments_count'] ?? widget.post['comments']);
    final hasMedia = _url.isNotEmpty;
    final ownerId = widget.post['user_id']?.toString();
    final ownerData = widget.post['users'] is Map
        ? Map<String, dynamic>.from(widget.post['users'] as Map)
        : const <String, dynamic>{};
    final ownerName = (ownerData['name'] ??
            (isArabic ? widget.post['name_ar'] : widget.post['name_en']) ??
            (isArabic ? 'زميل' : 'Colleague'))
        .toString();
    final ownerImage =
        (ownerData['profile_image'] ?? widget.post['profile_image'])
                ?.toString() ??
            '';
    final title = !hasMedia
        ? (isArabic ? 'المنشور' : 'Post')
        : widget.isVideo
            ? (isArabic ? 'الفيديو' : 'Video')
            : (isArabic ? 'الصورة' : 'Image');

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: _controlsVisible
            ? AppBar(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                title: Text(title),
                actions: [
                    IconButton(
                        tooltip: 'تنزيل إلى الهاتف',
                        icon: const Icon(Icons.download_outlined),
                        onPressed: () => WatermarkedDownloadService.download(
                            context,
                            type: 'post',
                            id: '${widget.post['id']}',
                            index: (widget.post['media_index'] as int?) ?? 0)),
                  ])
            : null,
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: hasMedia
                    ? Column(
                        children: [
                          Expanded(
                            child: Center(
                              child: widget.isVideo
                                  ? (widget.autoplayVideo
                                      ? (widget.videoActive
                                          ? VerticalAutoplayVideoPlayer(
                                              videoUrl: _url,
                                              onCompleted:
                                                  widget.onVideoCompleted,
                                              onControlsVisibilityChanged:
                                                  (visible) {
                                                if (mounted &&
                                                    _controlsVisible != visible)
                                                  setState(() =>
                                                      _controlsVisible =
                                                          visible);
                                              },
                                            )
                                          : const ColoredBox(
                                              color: Colors.black,
                                              child: Center(
                                                child: Icon(
                                                  Icons
                                                      .play_circle_outline_rounded,
                                                  color: Colors.white38,
                                                  size: 54,
                                                ),
                                              ),
                                            ))
                                      : VideoPlayerWidget(
                                          videoUrl: _url,
                                          onControlsVisibilityChanged:
                                              (visible) {
                                            if (mounted &&
                                                _controlsVisible != visible)
                                              setState(() =>
                                                  _controlsVisible = visible);
                                          },
                                        ))
                                  : GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => setState(() =>
                                          _controlsVisible = !_controlsVisible),
                                      child: InteractiveViewer(
                                        transformationController:
                                            _imageTransform,
                                        onInteractionUpdate: (_) => widget
                                            .onZoomChanged
                                            ?.call(_imageTransform.value
                                                    .getMaxScaleOnAxis() >
                                                1.01),
                                        minScale: 0.5,
                                        maxScale: 5,
                                        child: CachedMediaImage(
                                          url: _url,
                                          fit: BoxFit.contain,
                                          fallback: const Icon(
                                            Icons.broken_image_outlined,
                                            color: Colors.white54,
                                            size: 64,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          if (_controlsVisible && text.trim().isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.fromLTRB(16, 10, 16, 12),
                              color: Colors.black,
                              child: CopyableText(
                                text,
                                style: TextStyle(
                                    color: Colors.white, height: 1.45),
                              ),
                            ),
                        ],
                      )
                    : Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(28),
                          child: Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(maxWidth: 720),
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: CopyableText(
                              text,
                              textAlign: TextAlign.start,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                height: 1.65,
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
              if (_controlsVisible)
                Material(
                  color: Colors.black,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: ownerImage.isNotEmpty
                          ? NetworkImage(ownerImage)
                          : null,
                      child: ownerImage.isEmpty
                          ? const Icon(Icons.person_rounded)
                          : null,
                    ),
                    title: VerifiedName(
                        userId: widget.post['user_id']?.toString(),
                        child: Text(
                          ownerName,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        )),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: AppTheme.accent,
                      size: 16,
                    ),
                    onTap: ownerId == null || ownerId.isEmpty
                        ? null
                        : () => _openUserProfile(context, ownerId),
                  ),
                ),
              if (_controlsVisible)
                Container(
                  color: Colors.black.withAlpha(240),
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          IconButton(
                            tooltip: isArabic ? 'إعجاب' : 'Like',
                            onPressed: _toggleLike,
                            icon: Icon(
                              liked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: liked ? accentColor : Colors.white,
                            ),
                          ),
                          if (FeatureControl.instance.visible('comments'))
                            IconButton(
                              tooltip: isArabic ? 'تعليق' : 'Comment',
                              onPressed: () => _commentFocus.requestFocus(),
                              icon: Icon(Icons.comment_outlined,
                                  color: Colors.white),
                            ),
                          IconButton(
                            tooltip: isArabic ? 'مشاركة' : 'Share',
                            onPressed: _share,
                            icon:
                                Icon(Icons.share_rounded, color: Colors.white),
                          ),
                          if (FeatureControl.instance.visible('saved_posts'))
                            IconButton(
                              tooltip: isArabic ? 'حفظ' : 'Save',
                              onPressed: _toggleSave,
                              icon: Icon(
                                saved
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_border_rounded,
                                color: saved ? accentColor : Colors.white,
                              ),
                            ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              focusNode: _commentFocus,
                              groupId: _commentFocus,
                              minLines: 1,
                              maxLines: 3,
                              style: TextStyle(color: Colors.white),
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.newline,
                              onEditingComplete: () {},
                              decoration: InputDecoration(
                                hintText: isArabic
                                    ? 'اكتب تعليقًا...'
                                    : 'Write a comment...',
                                hintStyle:
                                    const TextStyle(color: Colors.white54),
                                filled: true,
                                fillColor: Colors.white10,
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          KeepKeyboardSendButton(
                              composerFocus: _commentFocus,
                              onSend: () => _addComment(isArabic),
                              enabled: !_sendingComment,
                              busy: _sendingComment),
                        ],
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          onPressed: _openComments,
                          icon: const Icon(Icons.forum_outlined, size: 18),
                          label: Text(
                            isArabic
                                ? 'عرض التعليقات ($comments)'
                                : 'View comments ($comments)',
                          ),
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// POST ACTION
// ============================================================

class _VerticalPostVideoViewer extends StatefulWidget {
  final Map<String, dynamic> initialPost;

  final VoidCallback? onLikeChanged;
  const _VerticalPostVideoViewer(
      {required this.initialPost, this.onLikeChanged});

  @override
  State<_VerticalPostVideoViewer> createState() =>
      _VerticalPostVideoViewerState();
}

class _VerticalPostVideoViewerState extends State<_VerticalPostVideoViewer> {
  late final PageController _pageController;
  late List<Map<String, dynamic>> _posts;
  int _currentIndex = 0;
  int? _completedIndex;

  void _advanceCompleted(int index) {
    if (!mounted ||
        index != _currentIndex ||
        !_pageController.hasClients ||
        !(ModalRoute.of(context)?.isCurrent ?? true)) return;
    _completedIndex = index;
    if (index + 1 < _posts.length) {
      _completedIndex = null;
      _pageController.animateToPage(index + 1,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _posts = [widget.initialPost];
    _loadMoreVideos();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadMoreVideos() async {
    try {
      final rows = await Supabase.instance.client
          .from('posts')
          .select('*, users(name,profile_image)')
          .or('is_hidden.is.null,is_hidden.eq.false')
          .order('created_at', ascending: false)
          .limit(50);
      final resolvedRows = List<Map<String, dynamic>>.from(rows);
      // Players resolve only the visible video, avoiding a batch of 50 signing requests.
      final initialId = widget.initialPost['id']?.toString();
      final additional = <Map<String, dynamic>>[];
      for (final post in resolvedRows) {
        if (post['id']?.toString() == initialId) continue;
        final media = postMediaItems(post);
        final videoIndex = media.indexWhere((item) => item.isVideo);
        if (videoIndex < 0) continue;
        additional.add({
          ...post,
          'video_url': media[videoIndex].url,
          'media_index': videoIndex,
          'type': 'video'
        });
      }
      if (mounted) {
        setState(() => _posts = [widget.initialPost, ...additional]);
        final completed = _completedIndex;
        if (completed != null)
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _advanceCompleted(completed));
      }
    } catch (_) {
      // The current video remains available if loading the following feed fails.
    }
  }

  @override
  Widget build(BuildContext context) {
    AppearanceScope.observe(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _posts.length,
        onPageChanged: (index) {
          if (mounted)
            setState(() {
              _currentIndex = index;
              _completedIndex = null;
            });
        },
        itemBuilder: (_, index) => ZameelMediaViewer(
          key: ValueKey(_posts[index]['id'] ?? index),
          post: _posts[index],
          isVideo: true,
          enableVerticalPaging: false,
          autoplayVideo: true,
          videoActive: index == _currentIndex,
          onLikeChanged: index == 0 ? widget.onLikeChanged : null,
          onVideoCompleted: () => _advanceCompleted(index),
        ),
      ),
    );
  }
}

class _PostAction extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool active;
  final VoidCallback? onTap;
  final Color? color;
  final int? count;
  final VoidCallback? onCountTap;

  const _PostAction({
    required this.icon,
    required this.text,
    this.count,
    this.onCountTap,
    this.active = false,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    AppearanceScope.observe(context);
    return PostAction161(
        icon: icon,
        label: text,
        color: active ? accentColor : (color ?? AppTheme.legacySecondary),
        countText: count?.toString(),
        onPressed: onTap,
        onCountTap: onCountTap);
  }
}

// ============================================================
// TEXT POST
// ============================================================

class _TextPost extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback onLike;
  final List<Map<String, dynamic>> savedPosts;
  final bool isAdmin;
  final String? postOwnerId;
  final VoidCallback onDelete;
  final Future<void> Function(Map<String, dynamic>)? onShareToProfile;

  const _TextPost({
    required this.post,
    required this.onLike,
    required this.savedPosts,
    this.isAdmin = false,
    this.postOwnerId,
    required this.onDelete,
    this.onShareToProfile,
  });

  @override
  State<_TextPost> createState() => _TextPostState();
}

class _TextPostState extends State<_TextPost> {
  late bool _isOwner;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    _isOwner = widget.post['user_id'] == user?.id;
  }

  @override
  Widget build(BuildContext context) {
    AppearanceScope.observe(context);
    final bool liked = widget.post['liked'] ?? false;
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;
    final bool isSaved = widget.post['isSaved'] ?? false;
    final bool hasOrderedMedia = _hasOrderedPostMedia(widget.post);
    final bool canDelete = widget.isAdmin || _isOwner;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => _openUserProfile(
                context,
                widget.post['user_id']?.toString(),
              ),
              child: _PostOwnerAvatar(
                  imageUrl: widget.post['profile_image']?.toString(),
                  radius: 18.7),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openUserProfile(
                  context,
                  widget.post['user_id']?.toString(),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                          child: VerifiedName(
                              userId: widget.post['user_id']?.toString(),
                              child: Text(
                                isArabic
                                    ? widget.post['name_ar']
                                    : widget.post['name_en'],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppTheme.legacyForeground,
                                ),
                              ))),
                      const SizedBox.shrink()
                    ]),
                    const SizedBox(height: 3),
                    Text(
                      postMetadata157(widget.post, isArabic),
                      style: TextStyle(
                        color: AppTheme.legacySecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // زر "..." مع قائمة منبثقة
            PostReportMenu(
              onEdited: (row) {
                if (mounted) setState(() => widget.post.addAll(row));
              },
              post: widget.post,
              postId: widget.post['id']?.toString() ?? '',
              authorId: widget.post['user_id']?.toString(),
              ar: isArabic,
              canDelete: canDelete,
              onDelete: widget.onDelete,
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            if (hasOrderedMedia) return;
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ZameelMediaViewer(
                  post: widget.post,
                  isVideo: false,
                  onLikeChanged: () {
                    if (mounted) setState(() {});
                  },
                ),
              ),
            );
            if (mounted) setState(() {});
          },
          child: MentionContent158(
            isArabic ? widget.post['text_ar'] : widget.post['text_en'],
            kind: 'post',
            id: '${widget.post['id']}',
            header: true,
            style: TextStyle(
              color: AppTheme.legacyForeground,
              fontSize: 16,
              height: 1.6,
            ),
          ),
        ),
        if (hasOrderedMedia) ...[
          const SizedBox(height: 12),
          PostMediaGallery(
            post: widget.post,
            height: postMediaHeight(context),
            onOpen: (item, _) => _openOrderedPostMedia(
              context,
              widget.post,
              item,
              onLikeChanged: () {
                if (mounted) setState(() {});
              },
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _PostAction(
              count: _actionCount161(
                  widget.post['likes'] ?? widget.post['likes_count']),
              icon: liked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              text: isArabic ? 'إعجاب' : 'Like',
              onCountTap: () =>
                  _showPostLikesDialog(context, widget.post, isArabic),
              active: liked,
              onTap: widget.onLike,
              color: AppTheme.legacySecondary,
            ),
            _PostAction(
              count: _actionCount161(
                  widget.post['comments'] ?? widget.post['comments_count']),
              icon: Icons.comment_outlined,
              text: Translations.translate(
                'comments_title',
                languageProvider.currentLanguage,
              ),
              onTap: () async {
                if (!await FeatureControl.instance.check(context, 'comments'))
                  return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FeatureControl.instance.page(
                        'comments',
                        CommentsScreen(
                          post: widget.post,
                        )),
                  ),
                );
              },
              color: AppTheme.legacySecondary,
            ),
            if (FeatureControl.instance.visible('saved_posts'))
              _PostAction(
                icon: isSaved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                text: isArabic ? 'حفظ' : 'Save',
                active: isSaved,
                color: isSaved ? accentColor : AppTheme.legacySecondary,
                onTap: () {
                  setState(() {
                    widget.post['isSaved'] = !isSaved;
                    if (widget.post['isSaved']) {
                      widget.savedPosts.insert(
                        0,
                        widget.post,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isArabic ? '✅ تم حفظ المنشور' : 'Post saved',
                          ),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    } else {
                      widget.savedPosts.removeWhere(
                        (p) => p['text'] == widget.post['text'],
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isArabic
                                ? '🗑️ تم إلغاء الحفظ'
                                : 'Post removed from saved',
                          ),
                          backgroundColor: Colors.orange,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                  });
                },
              ),
            _PostAction(
              count: _actionCount161(
                  widget.post['shares'] ?? widget.post['shares_count']),
              icon: Icons.share_outlined,
              text: isArabic ? 'مشاركة' : 'Share',
              color: AppTheme.legacySecondary,
              onTap: () => showContentShare157(context,
                  id: '${widget.post['id']}', onProfile: () async {
                if (widget.onShareToProfile != null) {
                  await widget.onShareToProfile!(widget.post);
                }
              }),
            ),
          ],
        ),
        Divider(color: AppTheme.adaptiveGlassBorder, height: 20),
      ],
    );
  }
}
