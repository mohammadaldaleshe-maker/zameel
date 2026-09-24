import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../services/feature_control.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/language_provider.dart';
import '../../services_social.dart';
import '../../theme/app_theme.dart';
import '../../widgets/post_media_gallery.dart';
import '../profile/profile_screen.dart';

class CommentsScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  final String? highlightedCommentId;

  const CommentsScreen({
    super.key,
    required this.post,
    this.highlightedCommentId,
  });

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _composerFocus = FocusNode();

  bool _loading = true;
  bool _sending = false;
  List<Map<String, dynamic>> _comments = <Map<String, dynamic>>[];
  Set<String> _likedCommentIds = <String>{};
  Map<String, dynamic>? _replyingTo;

  SupabaseClient get db => Supabase.instance.client;
  String? get uid => db.auth.currentUser?.id;
  String get postId => widget.post['id']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    if (postId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final rows = await db
          .from('post_comments')
          .select(
            'id,post_id,user_id,content,created_at,updated_at,parent_comment_id,likes_count',
          )
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      final comments = List<Map<String, dynamic>>.from(rows);
      final profiles = await ZameelSocialService.loadUserProfiles(
        comments
            .map((comment) => comment['user_id']?.toString())
            .whereType<String>(),
      );
      for (final comment in comments) {
        comment['users'] = profiles[comment['user_id']?.toString()] ??
            const <String, dynamic>{};
      }
      final commentIds = comments
          .map((comment) => comment['id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();

      var liked = <String>{};
      final currentUserId = uid;
      if (currentUserId != null && commentIds.isNotEmpty) {
        final likeRows = await db
            .from('post_comment_likes')
            .select('comment_id')
            .eq('user_id', currentUserId)
            .inFilter('comment_id', commentIds);
        liked = List<Map<String, dynamic>>.from(likeRows)
            .map((row) => row['comment_id']?.toString())
            .whereType<String>()
            .toSet();
      }

      if (!mounted) return;
      setState(() {
        _comments = comments;
        _likedCommentIds = liked;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FeatureControl.errorMessage(error, 'تعذر تحميل التعليقات'))),
      );
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    final user = db.auth.currentUser;
    if (text.isEmpty || user == null || postId.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await db.from('post_comments').insert({
        'post_id': postId,
        'user_id': user.id,
        'content': text,
        'parent_comment_id': _replyingTo?['id']?.toString(),
      });
      _commentController.clear();
      if (mounted) setState(() => _replyingTo = null);
      await _loadComments();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(FeatureControl.errorMessage(error, 'تعذر إضافة التعليق'))),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startReply(Map<String, dynamic> comment) {
    setState(() => _replyingTo = comment);
    _composerFocus.requestFocus();
  }

  Future<void> _toggleCommentLike(Map<String, dynamic> comment) async {
    final currentUserId = uid;
    final commentId = comment['id']?.toString();
    if (currentUserId == null || commentId == null || commentId.isEmpty) return;

    final wasLiked = _likedCommentIds.contains(commentId);
    final previousCount = (comment['likes_count'] as num?)?.toInt() ?? 0;
    setState(() {
      if (wasLiked) {
        _likedCommentIds.remove(commentId);
      } else {
        _likedCommentIds.add(commentId);
      }
      comment['likes_count'] = (previousCount + (wasLiked ? -1 : 1)).clamp(0, 999999);
    });

    try {
      if (wasLiked) {
        await db
            .from('post_comment_likes')
            .delete()
            .eq('comment_id', commentId)
            .eq('user_id', currentUserId);
      } else {
        await db.from('post_comment_likes').upsert({
          'comment_id': commentId,
          'user_id': currentUserId,
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (wasLiked) {
          _likedCommentIds.add(commentId);
        } else {
          _likedCommentIds.remove(commentId);
        }
        comment['likes_count'] = previousCount;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FeatureControl.errorMessage(error, 'تعذر تحديث الإعجاب'))),
      );
    }
  }

  Future<void> _editComment(
    Map<String, dynamic> comment,
    bool isArabic,
  ) async {
    if (comment['user_id']?.toString() != uid) return;
    final controller = TextEditingController(
      text: comment['content']?.toString() ?? '',
    );
    final value = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isArabic ? 'تعديل التعليق' : 'Edit comment'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          autofocus: true,
          style: const TextStyle(color: Colors.black),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              controller.text.trim(),
            ),
            child: Text(isArabic ? 'حفظ' : 'Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty || uid == null) return;

    try {
      await db
          .from('post_comments')
          .update({
            'content': value,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', comment['id'])
          .eq('user_id', uid!);
      await _loadComments();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(FeatureControl.errorMessage(error, 'تعذر تعديل التعليق'))),
        );
      }
    }
  }

  Future<void> _deleteComment(
    Map<String, dynamic> comment,
    bool isArabic,
  ) async {
    if (comment['user_id']?.toString() != uid) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isArabic ? 'حذف التعليق؟' : 'Delete comment?'),
        content: Text(
          isArabic
              ? 'سيتم حذف التعليق وردوده المرتبطة به.'
              : 'The comment and its replies will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(isArabic ? 'حذف' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || uid == null) return;

    try {
      await db
          .from('post_comments')
          .delete()
          .eq('id', comment['id'])
          .eq('user_id', uid!);
      if (_replyingTo?['id']?.toString() == comment['id']?.toString() && mounted) {
        setState(() => _replyingTo = null);
      }
      await _loadComments();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(FeatureControl.errorMessage(error, 'تعذر حذف التعليق'))),
        );
      }
    }
  }

  Future<void> _openCommenterProfile(Map<String, dynamic> comment) async {
    final userId = comment['user_id']?.toString() ?? '';
    if (userId.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)),
    );
  }

  List<_ThreadedComment> _threadedComments() {
    final byParent = <String?, List<Map<String, dynamic>>>{};
    final ids = _comments
        .map((comment) => comment['id']?.toString())
        .whereType<String>()
        .toSet();

    for (final comment in _comments) {
      var parentId = comment['parent_comment_id']?.toString();
      if (parentId != null && !ids.contains(parentId)) parentId = null;
      byParent.putIfAbsent(parentId, () => <Map<String, dynamic>>[]).add(comment);
    }

    final result = <_ThreadedComment>[];
    final visited = <String>{};

    void append(Map<String, dynamic> comment, int depth) {
      final id = comment['id']?.toString() ?? '';
      if (id.isEmpty || !visited.add(id)) return;
      result.add(_ThreadedComment(comment, depth.clamp(0, 3).toInt()));
      for (final reply in byParent[id] ?? const <Map<String, dynamic>>[]) {
        append(reply, depth + 1);
      }
    }

    for (final root in byParent[null] ?? const <Map<String, dynamic>>[]) {
      append(root, 0);
    }
    for (final comment in _comments) {
      if (!visited.contains(comment['id']?.toString())) append(comment, 0);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Provider.of<LanguageProvider>(context).isArabic;
    final ownerName = isArabic
        ? (widget.post['name_ar'] ?? widget.post['users']?['name'] ?? 'مستخدم')
        : (widget.post['name_en'] ?? widget.post['users']?['name'] ?? 'User');
    final postText = isArabic
        ? (widget.post['text_ar'] ?? widget.post['text'] ?? '')
        : (widget.post['text_en'] ?? widget.post['text'] ?? '');
    final rawMedia = widget.post['media_items'];
    final hasOrderedMedia = rawMedia is List && rawMedia.isNotEmpty;
    final threaded = _threadedComments();

    return Directionality(
      textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isArabic ? 'التعليقات' : 'Comments'),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.background,
                border: Border(
                  bottom: BorderSide(color: AppTheme.muted.shade200),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (postText.toString().trim().isNotEmpty)
                    Text(
                      postText.toString(),
                      style: const TextStyle(fontSize: 15, height: 1.5),
                    ),
                  if (hasOrderedMedia) ...[
                    const SizedBox(height: 10),
                    PostMediaGallery(
                      post: widget.post,
                      height: 210,
                    ),
                  ] else if ((widget.post['image_url']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        widget.post['image_url'].toString(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: _imageForPost(widget.post),
                    child: _imageForPost(widget.post) == null
                        ? const Icon(Icons.person_outline)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ownerName.toString(),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text('${_comments.length}'),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : threaded.isEmpty
                      ? Center(
                          child: Text(
                            isArabic
                                ? 'لا توجد تعليقات بعد\nكن أول من يعلق!'
                                : 'No comments yet\nBe the first to comment!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.muted.shade600),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadComments,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: threaded.length,
                            itemBuilder: (_, index) {
                              final entry = threaded[index];
                              return _commentCard(
                                entry.comment,
                                entry.depth,
                                isArabic,
                              );
                            },
                          ),
                        ),
            ),
            if (_replyingTo != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                color: AppTheme.accentSoft,
                child: Row(
                  children: [
                    const Icon(Icons.reply_rounded, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isArabic
                            ? 'الرد على ${_commenterName(_replyingTo!)}'
                            : 'Replying to ${_commenterName(_replyingTo!)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => _replyingTo = null),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ],
                ),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        focusNode: _composerFocus,
                        controller: _commentController,
                        minLines: 1,
                        maxLines: 4,
                        style: const TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          hintText: _replyingTo == null
                              ? (isArabic ? 'اكتب تعليقك...' : 'Write a comment...')
                              : (isArabic ? 'اكتب ردك...' : 'Write a reply...'),
                          filled: true,
                          fillColor: AppTheme.muted.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => _addComment(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton.small(
                      onPressed: _sending ? null : _addComment,
                      child: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _commenterName(Map<String, dynamic> comment) {
    final user = comment['users'];
    if (user is Map) {
      final name = user['name']?.toString().trim() ?? '';
      if (name.isNotEmpty) return name;
      final username = user['username']?.toString().trim() ?? '';
      if (username.isNotEmpty) return username;
    }
    return 'زميل';
  }

  ImageProvider? _imageForPost(Map<String, dynamic> post) {
    final direct = post['profile_image']?.toString();
    final nested = post['users'] is Map
        ? (post['users']['profile_image']?.toString())
        : null;
    final url = (direct != null && direct.isNotEmpty)
        ? direct
        : (nested != null && nested.isNotEmpty ? nested : null);
    return url == null ? null : NetworkImage(url);
  }

  Widget _commentCard(
    Map<String, dynamic> comment,
    int depth,
    bool isArabic,
  ) {
    final user = comment['users'] is Map
        ? Map<String, dynamic>.from(comment['users'] as Map)
        : <String, dynamic>{};
    final displayName = user['name']?.toString().trim() ?? '';
    final username = user['username']?.toString().trim() ?? '';
    final name = displayName.isNotEmpty
        ? displayName
        : (username.isNotEmpty ? username : (isArabic ? 'مستخدم' : 'User'));
    final body = comment['content']?.toString() ?? '';
    final avatar = user['profile_image']?.toString();
    final mine = comment['user_id']?.toString() == uid;
    final commentId = comment['id']?.toString() ?? '';
    final liked = _likedCommentIds.contains(commentId);
    final likesCount = (comment['likes_count'] as num?)?.toInt() ?? 0;
    final created = DateTime.tryParse(comment['created_at']?.toString() ?? '')
        ?.toLocal();
    final createdRaw = DateTime.tryParse(comment['created_at']?.toString() ?? '');
    final updatedRaw = DateTime.tryParse(comment['updated_at']?.toString() ?? '');
    final edited = createdRaw != null &&
        updatedRaw != null &&
        updatedRaw.difference(createdRaw).inSeconds.abs() > 1;
    final highlighted = widget.highlightedCommentId == commentId;

    final horizontalIndent = (depth * 22).toDouble();
    return Padding(
      padding: EdgeInsetsDirectional.only(start: horizontalIndent),
      child: Card(
        color: highlighted ? AppTheme.accentSoft : null,
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => _openCommenterProfile(comment),
                customBorder: const CircleBorder(),
                child: CircleAvatar(
                  radius: depth == 0 ? 20 : 17,
                  backgroundImage: avatar != null && avatar.isNotEmpty
                      ? NetworkImage(avatar)
                      : null,
                  child: avatar == null || avatar.isEmpty
                      ? const Icon(Icons.person_outline, size: 18)
                      : null,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _openCommenterProfile(comment),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (mine)
                          PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            onSelected: (value) {
                              if (value == 'edit') {
                                _editComment(comment, isArabic);
                              } else if (value == 'delete') {
                                _deleteComment(comment, isArabic);
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text(isArabic ? 'تعديل' : 'Edit'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(isArabic ? 'حذف' : 'Delete'),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(body),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${created == null ? '' : DateFormat(isArabic ? 'yyyy/MM/dd • HH:mm' : 'MMM d, yyyy • HH:mm', isArabic ? 'ar' : 'en').format(created)}${edited ? (isArabic ? ' • تم التعديل' : ' • edited') : ''}',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.muted.shade600,
                          ),
                        ),
                        InkWell(
                          onTap: () => _toggleCommentLike(comment),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 3,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  liked
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  size: 16,
                                  color: liked ? Colors.redAccent : null,
                                ),
                                if (likesCount > 0) ...[
                                  const SizedBox(width: 3),
                                  Text('$likesCount'),
                                ],
                              ],
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _startReply(comment),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            minimumSize: const Size(0, 28),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.reply_rounded, size: 16),
                          label: Text(isArabic ? 'رد' : 'Reply'),
                        ),
                      ],
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

class _ThreadedComment {
  final Map<String, dynamic> comment;
  final int depth;

  const _ThreadedComment(this.comment, this.depth);
}
