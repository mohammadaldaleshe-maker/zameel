part of '../main.dart';

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
    final String type = post['type'] ?? 'text';

    if (type == 'video') {
      return _VideoPost(
        post: post,
        onLike: onLike,
        savedPosts: savedPosts,
        isAdmin: isAdmin,
        postOwnerId: postOwnerId,
        onDelete: onDelete,
        onShareToProfile: onShareToProfile,
      );
    }

    if (type == 'image') {
      return _ImagePost(
        post: post,
        onLike: onLike,
        savedPosts: savedPosts,
        isAdmin: isAdmin,
        postOwnerId: postOwnerId,
        onDelete: onDelete,
        onShareToProfile: onShareToProfile,
      );
    }

    return _TextPost(
      post: post,
      onLike: onLike,
      savedPosts: savedPosts,
      isAdmin: isAdmin,
      postOwnerId: postOwnerId,
      onDelete: onDelete,
      onShareToProfile: onShareToProfile,
    );
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
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    final bool liked = widget.post['liked'] ?? false;
    final bool isSaved = widget.post['isSaved'] ?? false;
    final String imageUrl = widget.post['image_url']?.toString() ?? '';
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
              child: _PostOwnerAvatar(imageUrl: widget.post['profile_image']?.toString(), radius: 22),
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
                    Text(
                      isArabic
                          ? (widget.post['name_ar'] ?? 'مستخدم').toString()
                          : (widget.post['name_en'] ?? 'User').toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${isArabic ? (widget.post['department_ar'] ?? '') : (widget.post['department_en'] ?? '')} • '
                      '${isArabic ? (widget.post['time_ar'] ?? '') : (widget.post['time_en'] ?? '')}',
                      style: const TextStyle(
                        color: Colors.white60,
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
            IconButton(
              icon: const Icon(
                Icons.more_horiz,
                color: Colors.white60,
              ),
              tooltip: isArabic ? 'المزيد' : 'More',
              onPressed: () {
                final user = Supabase.instance.client.auth.currentUser;
                final bool isOwner =
                    widget.post['user_id']?.toString() == user?.id;
                final bool canDelete = widget.isAdmin || isOwner;

                if (!canDelete) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isArabic
                            ? 'ليس لديك صلاحية لهذا المنشور'
                            : 'You do not have permission for this post',
                      ),
                    ),
                  );
                  return;
                }

                widget.onDelete();
              },
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
            child: Text(
              (isArabic ? widget.post['text_ar'] : widget.post['text_en'])
                  .toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.6,
              ),
            ),
          ),
        // ------------------------------------------------------
        // IMAGE
        // ------------------------------------------------------
        if (imageUrl.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
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
                height: 230,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    alignment: Alignment.center,
                    color: Colors.white10,
                    child: const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 50,
                    ),
                  ),
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: accentColor),
                    );
                  },
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        // ------------------------------------------------------
        // COUNTERS
        // ------------------------------------------------------
        Row(
          children: [
            Icon(
              Icons.favorite_rounded,
              size: 17,
              color: liked ? accentColor : Colors.white60,
            ),
            const SizedBox(width: 5),
            InkWell(
              onTap: () => _showPostLikesDialog(context, widget.post, isArabic),
              child: Text('${widget.post['likes'] ?? 0}', style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 14),
            const Icon(Icons.repeat_rounded, size: 16, color: Colors.white60),
            const SizedBox(width: 4),
            Text('${widget.post['shares'] ?? 0}', style: const TextStyle(color: Colors.white60)),
            const Spacer(),
            Text(
              '${widget.post['comments'] ?? 0} '
              '${Translations.translate(
                'comments_title',
                languageProvider.currentLanguage,
              )}',
              style: const TextStyle(
                color: Colors.white60,
              ),
            ),
          ],
        ),
        const Divider(
          color: Colors.white24,
          height: 25,
        ),
        // ------------------------------------------------------
        // ACTIONS
        // ------------------------------------------------------
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // LIKE
            _PostAction(
              icon: liked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              text: isArabic ? 'إعجاب' : 'Like',
              active: liked,
              onTap: widget.onLike,
              color: Colors.white70,
            ),
            // COMMENTS
            _PostAction(
              icon: Icons.comment_outlined,
              text: Translations.translate(
                'comments_title',
                languageProvider.currentLanguage,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CommentsScreen(
                      post: widget.post,
                    ),
                  ),
                );
              },
              color: Colors.white70,
            ),
            // SAVE
            _PostAction(
              icon: isSaved
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              text: isArabic ? 'حفظ' : 'Save',
              active: isSaved,
              color: isSaved ? accentColor : Colors.white70,
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
                      (p) => p['id'] == widget.post['id'] || p['text'] == widget.post['text'],
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isArabic ? 'تم إلغاء حفظ المنشور' : 'Post removed from saved',
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
              icon: Icons.share_outlined,
              text: isArabic ? 'مشاركة' : 'Share',
              color: Colors.white70,
              onTap: () async {
                if (widget.onShareToProfile != null) {
                  await widget.onShareToProfile!(widget.post);
                }
                final text = isArabic
                    ? (widget.post['text_ar'] ?? widget.post['text_en'] ?? '')
                    : (widget.post['text_en'] ?? widget.post['text_ar'] ?? '');
                await Clipboard.setData(ClipboardData(text: '$text'));
              },
            ),
          ],
        ),
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
    final bool liked = widget.post['liked'] ?? false;
    final String videoUrl = widget.post['video_url'] ??
        'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';
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
      child: _PostOwnerAvatar(imageUrl: widget.post['profile_image']?.toString(), radius: 22),
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
            Text(
              isArabic ? widget.post['name_ar'] : widget.post['name_en'],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${isArabic ? widget.post['department_ar'] : widget.post['department_en']} • '
              '${isArabic ? widget.post['time_ar'] : widget.post['time_en']}',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    ),
    if (widget.isAdmin ||
        widget.post['user_id'] ==
            Supabase.instance.client.auth.currentUser?.id)
      PopupMenuButton<String>(
        icon: const Icon(
          Icons.more_horiz,
          color: Colors.white60,
        ),
        onSelected: (value) {
          if (value == 'delete') {
            widget.onDelete();
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isArabic ? 'حذف' : 'Delete',
                ),
              ],
            ),
          ),
        ],
      )
    else
      const Icon(
        Icons.more_horiz,
        color: Colors.white60,
      ),
  ],
),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
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
              height: 230,
              width: double.infinity,
              child: VideoPlayerWidget(videoUrl: videoUrl),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          isArabic ? widget.post['text_ar'] : widget.post['text_en'],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          InkWell(onTap: () => _showPostLikesDialog(context, widget.post, isArabic), child: Row(children: [const Icon(Icons.favorite_rounded, size: 16, color: Colors.white60), const SizedBox(width: 4), Text('${widget.post['likes'] ?? 0}', style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w700))])),
          const SizedBox(width: 14),
          const Icon(Icons.repeat_rounded, size: 16, color: Colors.white60), const SizedBox(width: 4),
          Text('${widget.post['shares'] ?? 0}', style: const TextStyle(color: Colors.white60)),
          const Spacer(), Text('${widget.post['comments'] ?? 0} ${Translations.translate('comments_title', languageProvider.currentLanguage)}', style: const TextStyle(color: Colors.white60)),
        ]),
        const Divider(color: Colors.white24, height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _PostAction(
              icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              text: '${widget.post['likes'] ?? 0}',
              active: liked,
              onTap: widget.onLike,
              color: Colors.white70,
            ),
            _PostAction(
              icon: Icons.comment_rounded,
              text: '${widget.post['comments']}',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CommentsScreen(
                      post: widget.post,
                    ),
                  ),
                );
              },
              color: Colors.white70,
            ),
            _PostAction(
              icon: widget.post['isSaved'] == true
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              text: isArabic ? 'حفظ' : 'Save',
              color: widget.post['isSaved'] == true ? accentColor : Colors.white70,
              onTap: () {
                setState(() {
                  widget.post['isSaved'] = !(widget.post['isSaved'] == true);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      widget.post['isSaved'] == true
                          ? (isArabic ? '✅ تم حفظ الفيديو' : '✅ Video saved')
                          : (isArabic ? '🗑️ تم إلغاء حفظ الفيديو' : '🗑️ Video removed from saved'),
                    ),
                    backgroundColor: AppTheme.primary,
                  ),
                );
              },
            ),
            _PostAction(
              icon: Icons.share_rounded,
              text: isArabic ? 'مشاركة' : 'Share',
              color: Colors.white70,
              onTap: () async {
                if (widget.onShareToProfile != null) {
                  await widget.onShareToProfile!(widget.post);
                }
                final videoUrl = '${widget.post['video_url'] ?? widget.post['videoUrl'] ?? ''}';
                await Clipboard.setData(ClipboardData(text: videoUrl.isNotEmpty ? videoUrl : '${widget.post['text_ar'] ?? widget.post['text_en'] ?? ''}'));
              },
            ),
          ],
        ),
      ],
    );
  }
}

Future<void> _showPostLikesDialog(BuildContext context, Map<String, dynamic> post, bool isArabic) async {
  final postId = post['id'];
  if (postId == null) return;
  try {
    final rows = await Supabase.instance.client.from('likes').select('user_id, users(name, profile_image)').eq('post_id', postId).order('created_at', ascending: false);
    if (!context.mounted) return;
    showModalBottomSheet(context: context, showDragHandle: true, builder: (_) => Directionality(textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr, child: SizedBox(height: 480, child: Column(children: [Padding(padding: const EdgeInsets.all(16), child: Text(isArabic ? 'الأشخاص الذين أعجبوا بالمنشور' : 'People who liked this post', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))), Expanded(child: rows.isEmpty ? Center(child: Text(isArabic ? 'لا توجد إعجابات بعد' : 'No likes yet')) : ListView.builder(itemCount: rows.length, itemBuilder: (_, i) { final u = rows[i]['users']; final name = u is Map ? (u['name']?.toString() ?? 'User') : 'User'; final image = u is Map ? u['profile_image']?.toString() : null; return ListTile(leading: CircleAvatar(backgroundImage: image != null && image.isNotEmpty ? NetworkImage(image) : null, child: image == null || image.isEmpty ? const Icon(Icons.person) : null), title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700))); }))]))));
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحميل قائمة الإعجابات: $e')));
  }
}


// ============================================================
// MEDIA VIEWER
// ============================================================

class ZameelMediaViewer extends StatefulWidget {
  final Map<String, dynamic> post;
  final bool isVideo;
  final VoidCallback? onLikeChanged;

  const ZameelMediaViewer({
    super.key,
    required this.post,
    required this.isVideo,
    this.onLikeChanged,
  });

  @override
  State<ZameelMediaViewer> createState() => _ZameelMediaViewerState();
}

class _ZameelMediaViewerState extends State<ZameelMediaViewer> {
  bool _busy = false;
  bool _sendingComment = false;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocus = FocusNode();

  String get _url => (widget.isVideo
          ? (widget.post['video_url'] ?? widget.post['videoUrl'])
          : (widget.post['image_url'] ?? widget.post['imageUrl']))
      ?.toString() ??
      '';

  int _count(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  void dispose() {
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
        widget.post['likes_count'] = liked ? (oldCount > 0 ? oldCount - 1 : 0) : oldCount + 1;
        widget.post['likes'] = widget.post['likes_count'];
      });
      widget.onLikeChanged?.call();
      return;
    }

    setState(() => _busy = true);
    try {
      if (liked) {
        await Supabase.instance.client
            .from('likes')
            .delete()
            .eq('user_id', user.id)
            .eq('post_id', postId);
      } else {
        await Supabase.instance.client
            .from('likes')
            .upsert({'user_id': user.id, 'post_id': postId});
      }
      if (!mounted) return;
      setState(() {
        widget.post['liked'] = !liked;
        widget.post['likes_count'] = liked ? (oldCount > 0 ? oldCount - 1 : 0) : oldCount + 1;
        widget.post['likes'] = widget.post['likes_count'];
      });
      widget.onLikeChanged?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحديث الإعجاب: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleSave() async {
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
          SnackBar(content: Text('تعذر تحديث الحفظ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    final user = Supabase.instance.client.auth.currentUser;
    final postId = widget.post['id'];
    if (user != null && postId != null && widget.post['is_demo'] != true) {
      try {
        await Supabase.instance.client.from('shared_posts').upsert({
          'post_id': postId,
          'shared_by': user.id,
        }, onConflict: 'post_id,shared_by');
      } catch (_) {}
    }
    final currentShares = _count(widget.post['shares_count'] ?? widget.post['shares']);
    if (mounted) {
      setState(() {
        widget.post['shares_count'] = currentShares + 1;
        widget.post['shares'] = currentShares + 1;
      });
    }
    await SharePlus.instance.share(
      ShareParams(
        text: '${widget.post['text_ar'] ?? widget.post['text_en'] ?? ''}${_url.isEmpty ? '' : '\n$_url'}',
        subject: 'Zameel',
      ),
    );
  }

  Future<void> _copyLink() async {
    if (_url.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم نسخ الرابط ✓')),
      );
    }
  }

  Future<void> _addComment(bool isArabic) async {
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
      final currentComments = _count(widget.post['comments_count'] ?? widget.post['comments']);
      if (!mounted) return;
      setState(() {
        widget.post['comments_count'] = currentComments + 1;
        widget.post['comments'] = currentComments + 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isArabic ? 'تم إضافة التعليق ✓' : 'Comment added ✓')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic ? 'تعذر إضافة التعليق: $e' : 'Could not add comment: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  Future<void> _openComments() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CommentsScreen(post: widget.post)),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;
    final liked = widget.post['liked'] == true;
    final saved = widget.post['isSaved'] == true;
    final text = (isArabic
            ? (widget.post['text_ar'] ?? widget.post['text_en'])
            : (widget.post['text_en'] ?? widget.post['text_ar']))
        ?.toString() ??
        '';
    final comments = _count(widget.post['comments_count'] ?? widget.post['comments']);
    final hasMedia = _url.isNotEmpty;
    final title = !hasMedia
        ? (isArabic ? 'المنشور' : 'Post')
        : widget.isVideo
            ? (isArabic ? 'الفيديو' : 'Video')
            : (isArabic ? 'الصورة' : 'Image');

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(title),
        ),
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
                                  ? VideoPlayerWidget(videoUrl: _url)
                                  : InteractiveViewer(
                                      minScale: 0.5,
                                      maxScale: 5,
                                      child: Image.network(
                                        _url,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => const Icon(
                                          Icons.broken_image_outlined,
                                          color: Colors.white54,
                                          size: 64,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          if (text.trim().isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                              color: Colors.black,
                              child: Text(
                                text,
                                style: const TextStyle(color: Colors.white, height: 1.45),
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
                            child: Text(
                              text,
                              textAlign: TextAlign.start,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                height: 1.65,
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
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
                            liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: liked ? accentColor : Colors.white,
                          ),
                        ),
                        IconButton(
                          tooltip: isArabic ? 'تعليق' : 'Comment',
                          onPressed: () => _commentFocus.requestFocus(),
                          icon: const Icon(Icons.comment_outlined, color: Colors.white),
                        ),
                        IconButton(
                          tooltip: isArabic ? 'مشاركة' : 'Share',
                          onPressed: _share,
                          icon: const Icon(Icons.share_rounded, color: Colors.white),
                        ),
                        IconButton(
                          tooltip: isArabic ? 'حفظ' : 'Save',
                          onPressed: _toggleSave,
                          icon: Icon(
                            saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            color: saved ? accentColor : Colors.white,
                          ),
                        ),
                        if (hasMedia)
                          IconButton(
                            tooltip: isArabic ? 'نسخ الرابط' : 'Copy link',
                            onPressed: _copyLink,
                            icon: const Icon(Icons.link_rounded, color: Colors.white),
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            focusNode: _commentFocus,
                            minLines: 1,
                            maxLines: 3,
                            style: const TextStyle(color: Colors.white),
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _addComment(isArabic),
                            decoration: InputDecoration(
                              hintText: isArabic ? 'اكتب تعليقًا...' : 'Write a comment...',
                              hintStyle: const TextStyle(color: Colors.white54),
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
                        IconButton.filled(
                          onPressed: _sendingComment ? null : () => _addComment(isArabic),
                          icon: _sendingComment
                              ? const SizedBox(
                                  width: 17,
                                  height: 17,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.send_rounded),
                        ),
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
                        style: TextButton.styleFrom(foregroundColor: Colors.white70),
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

class _PostAction extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool active;
  final VoidCallback? onTap;
  final Color color;

  const _PostAction({
    required this.icon,
    required this.text,
    this.active = false,
    this.onTap,
    this.color = Colors.white70,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            color: active ? accentColor : color,
            size: 22,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: active ? accentColor : color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
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
    final bool liked = widget.post['liked'] ?? false;
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;
    final bool isSaved = widget.post['isSaved'] ?? false;
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
              child: _PostOwnerAvatar(imageUrl: widget.post['profile_image']?.toString(), radius: 22),
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
                    Text(
                      isArabic ? widget.post['name_ar'] : widget.post['name_en'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${isArabic ? widget.post['department_ar'] : widget.post['department_en']} • '
                      '${isArabic ? widget.post['time_ar'] : widget.post['time_en']}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // زر "..." مع قائمة منبثقة
            IconButton(
              icon: const Icon(
                Icons.more_horiz,
                color: Colors.white60,
              ),
              tooltip: isArabic ? 'المزيد' : 'More',
              onPressed: () {
                final user = Supabase.instance.client.auth.currentUser;
                final bool isOwner =
                    widget.post['user_id']?.toString() == user?.id;
                final bool canDelete = widget.isAdmin || isOwner;

                if (!canDelete) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isArabic
                            ? 'ليس لديك صلاحية لهذا المنشور'
                            : 'You do not have permission for this post',
                      ),
                    ),
                  );
                  return;
                }

                widget.onDelete();
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
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
          child: Text(
            isArabic ? widget.post['text_ar'] : widget.post['text_en'],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.6,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              Icons.favorite_rounded,
              size: 17,
              color: liked ? accentColor : Colors.white60,
            ),
            const SizedBox(width: 5),
            InkWell(
              onTap: () => _showPostLikesDialog(context, widget.post, isArabic),
              child: Text('${widget.post['likes'] ?? 0}', style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 20),
            const Icon(Icons.repeat_rounded, size: 16, color: Colors.white60),
            const SizedBox(width: 4),
            Text('${widget.post['shares'] ?? 0}', style: const TextStyle(color: Colors.white60)),
            const SizedBox(width: 20),
            Text(
              '${widget.post['comments'] ?? 0} ${Translations.translate('comments_title', languageProvider.currentLanguage)}',
              style: const TextStyle(color: Colors.white60),
            ),
          ],
        ),
        const Divider(
          color: Colors.white24,
          height: 25,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _PostAction(
              icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              text: isArabic ? 'إعجاب' : 'Like',
              active: liked,
              onTap: widget.onLike,
              color: Colors.white70,
            ),
            _PostAction(
              icon: Icons.comment_outlined,
              text: Translations.translate(
                'comments_title',
                languageProvider.currentLanguage,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CommentsScreen(
                      post: widget.post,
                    ),
                  ),
                );
              },
              color: Colors.white70,
            ),
            _PostAction(
              icon: isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              text: isArabic ? 'حفظ' : 'Save',
              active: isSaved,
              color: isSaved ? accentColor : Colors.white70,
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
                          isArabic ? '🗑️ تم إلغاء الحفظ' : 'Post removed from saved',
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
              icon: Icons.share_outlined,
              text: isArabic ? 'مشاركة' : 'Share',
              color: Colors.white70,
              onTap: () async {
                if (widget.onShareToProfile != null) {
                  await widget.onShareToProfile!(widget.post);
                }
                final text = isArabic
                    ? (widget.post['text_ar'] ?? widget.post['text_en'] ?? '')
                    : (widget.post['text_en'] ?? widget.post['text_ar'] ?? '');
                await Clipboard.setData(ClipboardData(text: '$text'));
              },
            ),
          ],
        ),
      ],
    );
  }
}
