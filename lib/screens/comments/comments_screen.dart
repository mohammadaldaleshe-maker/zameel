import '../../widgets/keep_keyboard_send_button.dart';
import '../../widgets/mention_field156.dart';
import '../../widgets/mention_content158.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/comment_images156.dart';
import '../../platform/local_image_widget.dart';
import '../../widgets/cached_media_image.dart';
import 'package:zameel/widgets/copyable_text.dart';
import 'package:zameel/theme/appearance_controller.dart';
import 'package:zameel/widgets/verified_name.dart';

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

class _CommentsScreenState extends State<CommentsScreen>
    with WidgetsBindingObserver {
  final MentionController156 _commentController = MentionController156();
  final FocusNode _composerFocus = FocusNode();

  final _pickedImages156 = <XFile>[];
  Future<void> _pickImages156() async {
    if (_sending || _pickedImages156.length >= 5) return;
    try {
      final files = await ImagePicker()
          .pickMultiImage(imageQuality: 90, limit: 5 - _pickedImages156.length);
      if (mounted)
        setState(() =>
            _pickedImages156.addAll(files.take(5 - _pickedImages156.length)));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تعذر اختيار الصور')));
    }
  }

  bool _keyboardSeenForFocus = false;
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
    WidgetsBinding.instance.addObserver(this);
    _composerFocus.addListener(_composerChanged);
    _loadComments();
  }

  void _composerChanged() {
    if (!_composerFocus.hasFocus) _keyboardSeenForFocus = false;
    if (mounted) setState(() {});
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    if (View.of(context).viewInsets.bottom > 0) {
      _keyboardSeenForFocus = true;
    }
    setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _commentController.dispose();
    _composerFocus.removeListener(_composerChanged);
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
            'id,post_id,user_id,content,created_at,updated_at,parent_comment_id,likes_count,image_paths156',
          )
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      final comments = List<Map<String, dynamic>>.from(rows);
      try {
        await CommentImages156.resolve(comments);
      } catch (_) {
        /* Keep text comments available if image signing is temporarily unavailable. */
      }
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
        SnackBar(
          content: Text(
            FeatureControl.errorMessage(error, 'تعذر تحميل التعليقات'),
          ),
        ),
      );
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    final user = db.auth.currentUser;
    if ((text.isEmpty && _pickedImages156.isEmpty) ||
        user == null ||
        postId.isEmpty ||
        _sending) return;

    setState(() => _sending = true);
    try {
      final paths = await CommentImages156.upload(
          postId, List<XFile>.from(_pickedImages156));
      if (db.auth.currentUser?.id != user.id)
        throw StateError('account_changed');
      await db.from('post_comments').insert({
        'post_id': postId,
        'user_id': user.id,
        'content': text.isEmpty ? '📷' : text,
        'mention_ids156': _commentController.mentionIds,
        'image_paths156': paths,
        'parent_comment_id': _replyingTo?['id']?.toString(),
      });
      _commentController.clear();
      if (mounted)
        setState(() {
          _replyingTo = null;
          _pickedImages156.clear();
        });
      await _loadComments();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              FeatureControl.errorMessage(error, 'تعذر إضافة التعليق'),
            ),
          ),
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
      comment['likes_count'] = (previousCount + (wasLiked ? -1 : 1)).clamp(
        0,
        999999,
      );
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
        SnackBar(
          content: Text(
            FeatureControl.errorMessage(error, 'تعذر تحديث الإعجاب'),
          ),
        ),
      );
    }
  }

  Future<void> _editComment(Map<String, dynamic> comment, bool isArabic) async {
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
          style: TextStyle(color: AppTheme.adaptiveText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
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
          SnackBar(
            content: Text(
              FeatureControl.errorMessage(error, 'تعذر تعديل التعليق'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteComment(
    Map<String, dynamic> comment,
    bool isArabic,
  ) async {
    if (widget.post['user_id']?.toString() != uid) return;
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
      await db.rpc('zameel_delete_comment161',
          params: {'p_kind': 'post', 'p_id': comment['id']});
      if (_replyingTo?['id']?.toString() == comment['id']?.toString() &&
          mounted) {
        setState(() => _replyingTo = null);
      }
      await _loadComments();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              FeatureControl.errorMessage(error, 'تعذر حذف التعليق'),
            ),
          ),
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
      byParent
          .putIfAbsent(parentId, () => <Map<String, dynamic>>[])
          .add(comment);
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
    AppearanceScope.observe(context);
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
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Text(isArabic ? 'التعليقات' : 'Comments'),
          centerTitle: true,
        ),
        body: Padding(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              if (!(_composerFocus.hasFocus && !_keyboardSeenForFocus) &&
                  MediaQuery.viewInsetsOf(context).bottom == 0)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .35,
                  ),
                  child: SingleChildScrollView(
                    key: const ValueKey('comment-post-preview'),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.adaptiveBackground,
                        border: Border(
                          bottom: BorderSide(
                            color: AppTheme.adaptiveMuted.shade200,
                          ),
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
                            PostMediaGallery(post: widget.post, height: 210),
                          ] else if ((widget.post['image_url']?.toString() ??
                                  '')
                              .isNotEmpty) ...[
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(
                                widget.post['image_url'].toString(),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
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
                      child: VerifiedName(
                        userId: widget.post['user_id']?.toString(),
                        child: Text(
                          ownerName.toString(),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
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
                              style: TextStyle(
                                color: AppTheme.adaptiveMuted.shade600,
                              ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  color: AppTheme.adaptiveHighlight,
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
              if (_pickedImages156.isNotEmpty &&
                  View.of(context).viewInsets.bottom == 0)
                SizedBox(
                    height: 82,
                    child:
                        ListView(scrollDirection: Axis.horizontal, children: [
                      for (var i = 0; i < _pickedImages156.length; i++)
                        SizedBox(
                            width: 82,
                            child: Stack(children: [
                              localImageFromPath(_pickedImages156[i].path,
                                  width: 78, height: 78, fit: BoxFit.cover),
                              Positioned(
                                  top: 0,
                                  right: 0,
                                  child: IconButton(
                                      tooltip: 'إزالة الصورة',
                                      onPressed: _sending
                                          ? null
                                          : () => setState(() =>
                                              _pickedImages156.removeAt(i)),
                                      icon: const Icon(Icons.close,
                                          color: Colors.red)))
                            ]))
                    ])),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      TextFieldTapRegion(
                          groupId: _composerFocus,
                          child: IconButton(
                              tooltip:
                                  'إضافة صور (${_pickedImages156.length}/5)',
                              onPressed:
                                  _sending || _pickedImages156.length >= 5
                                      ? null
                                      : _pickImages156,
                              icon: Badge(
                                  label: Text('${_pickedImages156.length}'),
                                  isLabelVisible: _pickedImages156.isNotEmpty,
                                  child: const Icon(
                                      Icons.add_photo_alternate_outlined)))),
                      Expanded(
                        child: MentionTextField156(
                          key: const ValueKey('comment-composer'),
                          groupId: _composerFocus,
                          focusNode: _composerFocus,
                          onEditingComplete: () {},
                          controller: _commentController,
                          minLines: 1,
                          maxLines: 4,
                          style: TextStyle(color: AppTheme.adaptiveText),
                          decoration: InputDecoration(
                            hintText: _replyingTo == null
                                ? (isArabic
                                    ? 'اكتب تعليقك...'
                                    : 'Write a comment...')
                                : (isArabic
                                    ? 'اكتب ردك...'
                                    : 'Write a reply...'),
                            filled: true,
                            fillColor: AppTheme.adaptiveMuted.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextFieldTapRegion(
                        groupId: _composerFocus,
                        child: KeepKeyboardSendButton(
                            composerFocus: _composerFocus,
                            onSend: _addComment,
                            busy: _sending,
                            enabled: !_sending),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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

  Widget _commentCard(Map<String, dynamic> comment, int depth, bool isArabic) {
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
    final created =
        DateTime.tryParse(comment['created_at']?.toString() ?? '')?.toLocal();
    final createdRaw = DateTime.tryParse(
      comment['created_at']?.toString() ?? '',
    );
    final updatedRaw = DateTime.tryParse(
      comment['updated_at']?.toString() ?? '',
    );
    final edited = createdRaw != null &&
        updatedRaw != null &&
        updatedRaw.difference(createdRaw).inSeconds.abs() > 1;
    final highlighted = widget.highlightedCommentId == commentId;

    final horizontalIndent = (depth * 22).toDouble();
    return Padding(
      padding: EdgeInsetsDirectional.only(start: horizontalIndent),
      child: Card(
        color: highlighted ? AppTheme.adaptiveHighlight : null,
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
                              child: VerifiedName(
                                userId: comment['user_id']?.toString(),
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (mine || widget.post['user_id']?.toString() == uid)
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
                              if (mine)
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text(isArabic ? 'تعديل' : 'Edit'),
                                ),
                              if (widget.post['user_id']?.toString() == uid)
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(isArabic ? 'حذف' : 'Delete'),
                                ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    MentionContent158(body,
                        kind: 'post_comment', id: '${comment['id']}'),
                    if (comment['image_urls156'] is List)
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final url in comment['image_urls156'])
                          InkWell(
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => Scaffold(
                                          appBar: AppBar(
                                              title:
                                                  const Text('صورة التعليق')),
                                          body: Center(
                                              child: InteractiveViewer(
                                                  child: CachedMediaImage(
                                                      url: '$url',
                                                      fit: BoxFit.contain,
                                                      fallback: const Icon(Icons
                                                          .image_not_supported_outlined))))))),
                              child: SizedBox(
                                  width: 90,
                                  height: 90,
                                  child: CachedMediaImage(
                                      url: '$url',
                                      fit: BoxFit.cover,
                                      fallback: const Icon(
                                          Icons.image_not_supported_outlined))))
                      ]),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${created == null ? '' : DateFormat(isArabic ? 'yyyy/MM/dd • HH:mm' : 'MMM d, yyyy • HH:mm', isArabic ? 'ar' : 'en').format(created)}${edited ? (isArabic ? ' • تم التعديل' : ' • edited') : ''}',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.adaptiveMuted.shade600,
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
